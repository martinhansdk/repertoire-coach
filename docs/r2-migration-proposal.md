# Cloudflare R2 Migration Proposal (Keep Supabase DB/Auth)

## Objective
Migrate audio object storage from Supabase Storage to Cloudflare R2 while keeping:
- Supabase Postgres as the system of record
- Supabase Auth for identity/session
- Existing choir-member authorization semantics

This migration also closes an existing security hole: audio files are currently world-readable
by anyone with the URL (see Current State below).

## Current State (Codebase)

### Upload
- `AudioStorageService._uploadAudio()` uploads bytes via the Supabase Storage SDK, then calls
  `getPublicUrl()` to get a permanent URL stored in `tracks.audio_url`.
  - `lib/core/services/audio_storage_service.dart:122` (storage path construction)
  - `lib/core/services/audio_storage_service.dart:139–141` (`getPublicUrl` call)
- New tracks persist both `audio_url` and `storage_path`:
  - `lib/presentation/widgets/add_track_dialog.dart:140–141`

### Playback
- The main play path (`AudioPlayerControls.playTrack`) calls `createSignedUrl` (24 h TTL) when a
  `storagePath` is available, then passes the result to the repository:
  - `lib/presentation/providers/audio_player_provider.dart:74–82`
- If `createSignedUrl` fails, playback falls back to `track.audioUrl` (the permanent public URL):
  - `lib/data/repositories/audio_player_repository_impl.dart:214`
- The Android Auto / background-service handler (`_AudioPlayerHandler._playTrackById`) also
  independently calls `createSignedUrl` and falls back to `trackRow.audioUrl`:
  - `lib/data/repositories/audio_player_repository_impl.dart:508–518`

### Delete / existence checks
- `AudioStorageService.deleteAudio()` removes objects via the Supabase Storage SDK:
  - `lib/core/services/audio_storage_service.dart:159–167`
- `AudioStorageService.audioExists()` lists bucket contents to check for a file:
  - `lib/core/services/audio_storage_service.dart:174–185`

### Security posture (important)
The bucket is `public = true` (`supabase/migrations/002_create_audio_storage_bucket.sql:7`).
This means **`getPublicUrl()` returns a URL that anyone can fetch with no authentication**.
The RLS policies in that migration only gate Supabase Storage API access; they do not protect
the public CDN URL. The `createSignedUrl` call at playback time adds time-limiting, but because
the fallback is the permanent public URL, a determined user can bypass it.

The stored `audio_url` values in the `tracks` table are fully public links. This is the primary
security motivation for this migration, beyond cost/control reasons.

## Target Architecture
- Storage provider: Cloudflare R2 (`audio-files-prod`)
- Database/Auth: Supabase (unchanged)
- Access model:
  1. Client requests short-lived signed URL from a server-side signer endpoint.
  2. Signer validates Supabase JWT and choir membership in Postgres.
  3. Signer returns R2 presigned URL (GET for playback, PUT for upload).
- No permanent public audio URLs. R2 bucket stays private.

## Authorization Model (RLS Replacement)
R2 does not support Postgres RLS. Enforce authorization when issuing presigned URLs.

Signer endpoints:
1. `POST /audio/sign/play`
   - Input: `trackId` (or `storagePath`)
   - Checks: authenticated user belongs to track's choir
   - Output: presigned GET URL, TTL 1–4 hours (see Security Controls)
2. `POST /audio/sign/upload`
   - Input: `choirId`, `trackId`, `extension`, `contentType`
   - Checks: authenticated user belongs to choir
   - Output: presigned PUT URL + canonical object key, TTL 5–10 minutes
3. `POST /audio/sign/delete`
   - Input: `storagePath`, `trackId`
   - Checks: authenticated user belongs to track's choir
   - Required (not optional) — without it, deleted tracks leave orphaned R2 objects permanently.

### Signer runtime: Supabase Edge Function

**Decision**: Supabase Edge Function (`audio-signer`).
- JWT verification and choir membership check are native — no extra round-trips.
- R2 presigning uses `aws4fetch` (ESM, purpose-built for edge runtimes including Deno).
- **Before starting implementation**: verify `aws4fetch` works in Supabase Edge Functions with
  a minimal smoke test (sign a dummy request and check the output). This is the one unknown
  in this approach and cheap to validate upfront.

## Data Model Changes
Keep `storage_path` as canonical key. Add provider metadata and deprecate stored public URL.

Recommended DB changes (`tracks`):
- Add `storage_provider text not null default 'supabase'` with check constraint (`supabase`, `r2`)
- Keep `storage_path text`
- Keep `audio_url text` for backward compatibility during transition; stop writing it for R2 tracks
  and stop reading it as a playback source once all rows are migrated

## Application Changes

### Upload Flow
Current:
- `AudioStorageService` uploads via the Supabase Storage SDK, which handles auth transparently.

Target:
1. Call `POST /audio/sign/upload` with Supabase JWT → receive presigned PUT URL + object key.
2. Upload bytes to R2 via a **raw HTTP PUT** request (no SDK — use the `http` package directly).
   The Supabase SDK has no R2 path; this requires new HTTP client code in `AudioStorageService`.
   Upload progress reporting must be handled explicitly (the current SDK path provides this
   implicitly).
3. Save `storage_path` (= object key) + `storage_provider='r2'` in `tracks`. Do not write
   `audio_url` for new R2 tracks.

Files to change:
- `lib/core/services/audio_storage_service.dart` — new upload path; `AudioUploadResult` no longer
  returns a meaningful `audioUrl` for R2 tracks (return `null` or omit the field)
- `lib/presentation/widgets/add_track_dialog.dart` — handle `audioUrl` being null
- `lib/data/datasources/remote/remote_track_data_source.dart`

### Playback Flow
Current:
- Two independent places call `createSignedUrl`: `AudioPlayerControls.playTrack` (main UI path)
  and `_AudioPlayerHandler._playTrackById` (Android Auto / background service path).

Target:
- In both places, when `storage_provider = 'r2'`, call `POST /audio/sign/play` instead of the
  Supabase `createSignedUrl`. Keep the Supabase signed-URL path for rows where
  `storage_provider = 'supabase'` (transition period).
- The signer call is a regular authenticated HTTP request (Bearer token = Supabase JWT).
- `_AudioPlayerHandler` currently has no HTTP client. It will need one injected (e.g., a signer
  client passed in alongside `SupabaseService`).

Files to change:
- `lib/presentation/providers/audio_player_provider.dart`
- `lib/data/repositories/audio_player_repository_impl.dart` — **both** `AudioPlayerRepositoryImpl`
  (main play path) and `_AudioPlayerHandler` (Android Auto path)

### Delete Flow
Current:
- `AudioStorageService.deleteAudio()` calls the Supabase SDK directly.

Target:
- When `storage_provider = 'r2'`, call `POST /audio/sign/delete` (or call R2 S3 API delete
  directly from the signer, triggered by the client request).
- Keep the Supabase path for `storage_provider = 'supabase'` rows.

Files to change:
- `lib/core/services/audio_storage_service.dart`
- Wherever track deletion is initiated (confirm `deleteAudio` is always called on track removal)

### Existence Check
Current:
- `AudioStorageService.audioExists()` calls the Supabase Storage list API.

Target:
- For R2 objects, check existence via the signer endpoint or a dedicated
  `POST /audio/sign/exists` call, or accept that existence can be inferred from `storage_path`
  being non-null (and handle 404 at playback time instead).
- Evaluate whether `audioExists()` is called in any user-facing path; if it is only used
  defensively, handling 404 at playback start may be sufficient.

### Feature Flag Mechanism
To support dual-read during the transition (Phase 2), the app needs to know whether to use the
R2 path. Recommended approach: **use `storage_provider` from the DB row as the flag** — no
separate feature flag needed. Each `Track` object already carries `storagePath`; add
`storageProvider` to the `Track` entity. The playback/upload code branches on this value.

For upload cutover (Phase 3), use a **compile-time `dart-define`** or a **remote config value**
fetched from Supabase at startup. `dart-define` is simpler and avoids a network round-trip; a
remote config (e.g., a row in a `config` table) allows toggling without a release. Decide based
on how quickly you need to be able to roll back.

## R2 Bucket Configuration

### CORS (web platform)
The web build is hosted on Cloudflare Pages (`*.pages.dev`). The production origin is
`https://<project-name>.pages.dev` — replace with the actual project name.

R2 CORS (AWS S3 format) does not support subdomain wildcards, so origins must be listed
explicitly. Preview deployments that need to test audio uploads should be added individually,
or tested against production credentials.

```json
[
  {
    "AllowedOrigins": [
      "https://<project-name>.pages.dev",
      "http://localhost:8080"
    ],
    "AllowedMethods": ["GET", "PUT"],
    "AllowedHeaders": ["Content-Type", "Content-Length"],
    "MaxAgeSeconds": 3600
  }
]
```

Do not use `"*"` for `AllowedOrigins` — a wildcard would allow any site to PUT audio to the
bucket using your users' upload tokens.

### Other bucket settings
- Bucket access: **private** (no public access, unlike current Supabase bucket)
- Lifecycle policy: optional; consider expiring incomplete multipart uploads after 24 h

## Migration Phases
1. **Prepare**
   - Create R2 bucket (private), generate R2 API credentials (Access Key + Secret for S3 API).
   - Configure CORS on bucket (see above).
   - Ship DB migration adding `storage_provider` column.
   - Deploy and smoke-test signer endpoint(s) to staging.
2. **Dual-read** (no data move yet)
   - Ship app update: playback branches on `storage_provider`. All existing rows are `'supabase'`
     so real behavior is unchanged. New code paths are exercised by staging R2 test tracks.
3. **Dual-write cutover**
   - New uploads go to R2 only (`storage_provider='r2'`).
   - Stop writing `audio_url` for new tracks.
4. **Backfill historical objects**
   - Copy Supabase Storage objects to R2 via REST API download script (see Data Migration Execution).
   - Verify checksums/object counts, then update rows to `storage_provider='r2'`.
5. **Stabilize and remove legacy dependency**
   - Remove Supabase signed-URL code path (no more `supabase` provider rows in production).
   - Delete objects from Supabase Storage bucket.
   - Optionally remove `audio_url` column after confirming no reads.

## Data Migration Execution
The project is on the Supabase Free plan. The S3-compatible API is not available, so bulk copy
tools (`rclone`, `aws s3 cp`) cannot be used against Supabase Storage as a source.

1. **Export mapping from DB:**
   Query `tracks` for all rows with `storage_provider = 'supabase'` and a non-null
   `storage_path`. Record `track_id`, `storage_path`, and choir association.

2. **Download and re-upload via script:**
   Write a migration script (Node.js or Python) that, for each `storage_path`:
   - Downloads the object from Supabase Storage via the authenticated REST API:
     `GET /storage/v1/object/audio_files/{storage_path}` with a service-role JWT.
   - Uploads the bytes to R2 via the S3 API (using `aws-sdk` or `boto3` with R2 endpoint).
   - Records success/failure per object.
   Run in batches with a small delay to avoid rate-limiting Supabase Storage.

3. **Verification:**
   - Compare object count in R2 against the exported DB mapping.
   - Spot-check ETag / content-length for a sample of objects.

4. **DB update:**
   Set `storage_provider = 'r2'` only for rows whose objects were successfully verified in R2.

## Security Controls
- Presigned URL TTL:
  - **Playback: 24 hours.** Matches the previous Supabase signed-URL TTL. Avoids any
    expiry-during-session issues (paused tracks, background playback, Android Auto).
  - **Upload: 5–10 minutes.** Upload begins immediately after the signed URL is issued; short
    TTL is safe here.
- Validate choir membership on every sign request (not just upload).
- Restrict upload MIME types (`audio/mpeg`, `audio/mp4`, `audio/x-m4a`, `audio/wav`, `audio/ogg`)
  and enforce a maximum file size limit in the signer (not just the client).
- Log sign requests: `user_id`, `track_id`, `object_key`, `action`, timestamp.
- Add rate limiting on signer endpoints (per user, per IP).
- Keep R2 Access Key and Secret exclusively in the signer runtime's environment/secrets.
  Never expose them to the Flutter client.

## Observability and Operations
- Metrics:
  - Sign endpoint success/failure rate (per action: play/upload/delete)
  - R2 upload/playback error rates
  - Latency percentiles for sign + object fetch
- Alerts:
  - Elevated 401/403 from signer (auth/membership failures)
  - Elevated 404/5xx from R2 object requests

## Rollback Plan
- Maintain dual-read until stable in production.
- If R2 path fails:
  - Redeploy app with R2 code path removed (or flip compile-time flag if using remote config).
  - Route new uploads back to Supabase temporarily.
- Keep source objects in Supabase Storage during entire migration window.
  Do not delete legacy objects until Phase 5 validation passes.

## Estimated Effort
- Signer service + DB migration: 2–4 days
- Client integration (upload + playback + delete, including Android Auto handler): 3–5 days
- Backfill tooling + verification: 3–5 days (Free plan — REST API download script required)
- Staging soak + production rollout: 2–3 days

Total: 2–3 weeks calendar time including testing and staged rollout.

## Acceptance Criteria
- New uploads are stored in R2.
- Playback works for authorized choir members only (no unauthenticated access).
- Unauthorized users cannot obtain signed URLs.
- Existing tracks remain playable during migration.
- Android Auto playback works throughout the migration.
- Deleting a track removes the corresponding R2 object.
- Supabase storage usage drops after cleanup.

## Decisions Log

| Decision | Choice | Notes |
|----------|--------|-------|
| Signer runtime | Supabase Edge Function | Auth is native; verify `aws4fetch` in Deno before starting implementation |
| Web CORS origin | `https://<project-name>.pages.dev` + `http://localhost:8080` | Replace `<project-name>` with actual Cloudflare Pages project name |
| Backfill approach | REST API download + R2 re-upload script | Free plan — S3-compatible API not available; script downloads via Supabase Storage REST and re-uploads to R2 |
| Upload path | Direct client-to-R2 via presigned PUT | No server-side proxy; client does raw HTTP PUT |
| Feature flag mechanism | `storage_provider` DB column + compile-time `dart-define` for upload cutover | No separate flag needed for playback; upload cutover toggled by `dart-define` |
| URL TTL — playback | 24 hours | Matches previous Supabase TTL; avoids expiry during long sessions |
| URL TTL — upload | 5–10 minutes | Upload starts immediately after signing; short TTL is safe |
