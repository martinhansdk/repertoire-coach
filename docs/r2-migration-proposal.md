# Cloudflare R2 Migration Proposal (Keep Supabase DB/Auth)

## Objective
Migrate audio object storage from Supabase Storage to Cloudflare R2 while keeping:
- Supabase Postgres as the system of record
- Supabase Auth for identity/session
- Existing choir-member authorization semantics

## Current State (Codebase)
- Upload writes to Supabase Storage bucket `audio_files` and returns:
  - `storagePath`: `choirId/trackId.ext`
  - `audioUrl`: via `getPublicUrl(...)`
  - `lib/core/services/audio_storage_service.dart:122`
  - `lib/core/services/audio_storage_service.dart:141`
- New tracks persist both `audio_url` and `storage_path`:
  - `lib/presentation/widgets/add_track_dialog.dart:140`
  - `lib/presentation/widgets/add_track_dialog.dart:141`
- Playback path currently attempts a signed URL first (24h), then falls back to stored `audio_url`:
  - `lib/presentation/providers/audio_player_provider.dart:82`
  - `lib/data/repositories/audio_player_repository_impl.dart:214`
  - `lib/data/repositories/audio_player_repository_impl.dart:503`
- Storage bucket is created with `public = true`:
  - `supabase/migrations/002_create_audio_storage_bucket.sql:7`

## Target Architecture
- Storage provider: Cloudflare R2 (`audio-files-prod`)
- Database/Auth: Supabase (unchanged)
- Access model:
  1. Client requests short-lived signed URL from a server endpoint.
  2. Server validates Supabase JWT and choir membership in Postgres.
  3. Server returns R2 presigned URL (GET for playback, PUT for upload).
- No permanent public audio URLs.

## Authorization Model (RLS Replacement)
R2 does not support Postgres RLS. Enforce authorization when issuing presigned URLs.

Signer endpoints:
1. `POST /audio/sign/play`
   - Input: `trackId` (or `storagePath`)
   - Checks: authenticated user belongs to track's choir
   - Output: presigned GET URL, short TTL (5-15 min)
2. `POST /audio/sign/upload`
   - Input: `choirId`, `trackId`, `extension`, `contentType`
   - Checks: authenticated user belongs to choir
   - Output: presigned PUT URL + canonical object key
3. `POST /audio/sign/delete` (optional)
   - For controlled deletes and cleanup jobs

Implementation options:
- Supabase Edge Function (recommended first): simpler reuse of Supabase auth context.
- Cloudflare Worker: better edge alignment if you want R2 logic centralized at Cloudflare.

## Data Model Changes
Keep `storage_path` as canonical key. Add provider metadata and deprecate stored public URL.

Recommended DB changes (`tracks`):
- Add `storage_provider text not null default 'supabase'` with check (`supabase`, `r2`)
- Keep `storage_path text`
- Keep `audio_url text` temporarily for backward compatibility; stop using as source of truth

## Application Changes
### Upload Flow
Current:
- `AudioStorageService` directly uploads via Supabase Storage SDK.

Target:
1. Request presigned PUT URL from signer endpoint.
2. Upload bytes directly to R2.
3. Save `storage_path` + `storage_provider='r2'` in `tracks`.

Files expected to change:
- `lib/core/services/audio_storage_service.dart`
- `lib/presentation/widgets/add_track_dialog.dart`
- `lib/data/datasources/remote/remote_track_data_source.dart`

### Playback Flow
Current:
- Client asks Supabase Storage for signed URL (`createSignedUrl`) when `storagePath` exists.

Target:
- If `storage_provider='r2'`, call signer endpoint for R2 GET URL.
- Else keep existing Supabase signed URL path (transitional).

Files expected to change:
- `lib/presentation/providers/audio_player_provider.dart`
- `lib/data/repositories/audio_player_repository_impl.dart`

## Migration Phases
1. Prepare
   - Create R2 bucket, credentials, CORS, and lifecycle policy.
   - Ship DB migration adding `storage_provider`.
   - Deploy signer endpoint(s) to staging.
2. Dual-read (no data move yet)
   - Playback supports both providers.
   - New code path enabled behind feature flag.
3. Dual-write cutover
   - New uploads go to R2 only.
   - Persist `storage_provider='r2'`.
4. Backfill historical objects
   - Copy objects from Supabase Storage to R2.
   - Verify checksums/object counts.
   - Update corresponding rows to `storage_provider='r2'`.
5. Stabilize and remove legacy dependency
   - Remove `audio_url` playback fallback for R2 rows.
   - Optionally make Supabase bucket private or decommission old objects.

## Data Migration Execution
Suggested approach:
1. Export mapping from DB:
   - `track_id`, `storage_path`, choir association.
2. Bulk copy objects:
   - Source: Supabase S3-compatible endpoint
   - Target: R2 S3 API endpoint
3. Verification:
   - Object counts by prefix (`choirId/`)
   - Spot-check content length / checksum
4. DB update:
   - Set `storage_provider='r2'` only for verified rows

## Security Controls
- Presigned URL TTL:
  - Playback: 5-15 minutes
  - Upload: 1-5 minutes
- Validate membership on every sign request.
- Restrict upload MIME types and size limits.
- Log sign requests (`user_id`, `track_id`, `object_key`, `action`).
- Add endpoint rate limiting.
- Keep R2 secrets server-side only.

## Observability and Operations
- Metrics:
  - Sign endpoint success/failure rate
  - R2 upload/playback error rates
  - Latency percentiles for sign + object fetch
- Alerts:
  - Elevated 401/403 from signer
  - Elevated 404/5xx from R2 object requests

## Rollback Plan
- Maintain dual-read until stable in production.
- If R2 path fails:
  - Switch feature flag to Supabase path for playback/signing.
  - Route new uploads back to Supabase temporarily.
- Keep source objects during migration window; do not delete legacy data until validation passes.

## Estimated Effort
- Signer service + DB migration: 2-4 days
- Client integration (upload + playback): 2-4 days
- Backfill tooling + validation: 2-5 days
- Staging soak + production rollout: 2-3 days

Total expected: 2-3 weeks calendar time including testing and staged rollout.

## Acceptance Criteria
- New uploads are stored in R2.
- Playback works for authorized choir members only.
- Unauthorized users cannot obtain signed URLs.
- Existing tracks remain playable during migration.
- Supabase storage usage drops after cleanup.

## Open Decisions
1. Signer runtime:
   - Supabase Edge Function first, or Cloudflare Worker first.
2. Upload path:
   - Direct client-to-R2 via presigned PUT, or proxied upload endpoint.
3. URL TTL policy:
   - Exact values for web vs mobile playback behavior.
4. Cleanup schedule:
   - When to remove `audio_url` fallback and old Supabase objects.
