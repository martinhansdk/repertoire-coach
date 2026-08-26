---
name: sync-change
description: >
  Working procedure for any change touching synchronization: files under
  lib/core/sync/, lib/core/services/sync_service.dart, remote data sources
  in lib/data/datasources/remote/, sync-related columns in local Drift
  tables, or Supabase migrations affecting synced tables (choirs,
  choir_members, concerts, songs, tracks, marker_sets, favorite_tracks).
  Also use when investigating sync bugs ("changes not reaching other
  devices", "changes disappearing", items stuck unsynced) or when a
  property-test seed fails. Covers the invariants, the bug-fix protocol,
  schema-change protocol, and how to run all three sync test suites.
---

# Sync Change Procedure

Sync is this app's highest-risk subsystem: three prior overhauls, every field
bug caused by violating a property nobody had written down, or by a mismatch
between the client's model of the remote and the real Postgres. The design
and its **load-bearing invariants** live in `docs/SYNC_ARCHITECTURE.md` —
read that first, always. This skill is the working procedure around it.

## Before writing any code

1. Read `docs/SYNC_ARCHITECTURE.md`, especially the Invariants section.
2. Check your planned change against each invariant. In particular:
   - Deletion is a tombstone; never infer deletion from a row's absence.
   - `updated_at` = client-set edit time (UTC); never server- or push-time.
   - Repositories never write to Supabase; the sync layer owns remote I/O.
   - markSynced is conditional on the snapshotted timestamp; upserts never
     overwrite newer unsynced local rows.
   - Newest-wins holds at BOTH layers: the algorithm resolves against the
     snapshot it read, AND the remote tombstone UPDATE carries
     `.lte('updated_at', deletedAt)`. The algorithm calls `deleteOnRemote`
     even when the remote copy looks absent (a degraded read is "no
     information", not "no row"), so the write itself must be the guard.
     Without it an older deletion can clobber a newer remote edit.
   - Any new remote read for sync must page and chunk (see below).

## Fixing a sync bug (strict order)

1. **Write the failing test first.** Choose the lowest layer that can
   express the bug:
   - Algorithm/interleaving bug → `test/core/sync/sync_algorithm_test.dart`,
     as a new `REGRESSION: <property it protects>` test using
     `FakeSyncAdapter` (supports shared remotes for multi-device scenarios,
     `failingIds`, `remoteReadReturnsEmpty`, and mid-sync mutation hooks
     `onBeforeMarkSynced` / `onBeforeUpsertLocal`).
   - Real-SQL behavior → the Sync regressions group in
     `test/data/datasources/local/local_marker_data_source_test.dart`.
   - Server-side behavior (triggers, constraints, RLS, response caps) →
     `test/integration/supabase_sync_integration_test.dart`.
2. Confirm it fails, apply the fix, confirm it passes.
3. **Add the property to `docs/SYNC_ARCHITECTURE.md` → Invariants.** A
   2026-02 incident enshrined a data-destroying behavior WITH a passing
   test because the invariant it broke was unwritten. Test + invariant +
   fix ship in one commit.
4. Run the full sync suites (below) before committing.

## Schema change on a synced table

1. New migration file in `supabase/migrations/` (next number). It will be
   run MANUALLY in the Supabase dashboard — say so in the commit message.
   The Supabase MCP is read-only.
2. Synced tables require: `deleted BOOLEAN NOT NULL DEFAULT false` and a
   client-authoritative `updated_at TIMESTAMPTZ` with NO `BEFORE UPDATE`
   trigger touching it.
3. RLS: deletion is an UPDATE (`deleted := true`), so UPDATE policies must
   cover every principal that should be able to delete (the migration-013
   lesson).
4. Update the model's `toJson`/`fromJson`, the Drift table + a local
   migration, and the remote datasource's column list. A new entity's
   `deleteOnRemote` must be a soft-delete UPDATE guarded with
   `.lte('updated_at', deletedAt)` — copy an existing one rather than
   writing a plain UPDATE.
5. The schema-drift integration test compares `toJson()` keys against
   `information_schema` live — extend it for new models, and run it.
6. Run `mcp__supabase__get_advisors (type: "security")` after applying.

## New remote query for sync

Use the helpers in
`lib/data/datasources/remote/postgrest_pagination.dart`:
- `fetchAllRows((from, to) => ...query....order(<unique col>, ascending:
  true).range(from, to))` — pages past PostgREST's max-rows cap. The order
  MUST be total (unique), or pages can skip/repeat rows under concurrent
  writes. `pageSize` must not exceed the server's max-rows setting.
- `fetchAllRowsChunkedIn(ids, (chunk) => fetchAllRows(...))` — any
  `IN (...)` id list must be chunked; a few hundred UUIDs exceed gateway
  URL limits.

## Running the sync test suites

Flutter runs in Docker only — use the MCP tools or `scripts/test.sh`.

1. **Deterministic + property tests** (fast, no services):
   `mcp__flutter__flutter_test` on `test/core/sync/` — includes the
   multi-device model checker (~120 seeds). A failure message contains
   `seed=N`; rerun that single named test to reproduce deterministically.
2. **Drift-level regressions**: `test/data/datasources/local/`.
3. **Integration** (needs a local Supabase stack; usually CI does this via
   `.github/workflows/sync-integration.yml`):
   ```bash
   supabase start                # applies migrations + seed.sql
   supabase status -o env        # API_URL, ANON_KEY, SERVICE_ROLE_KEY
   SUPABASE_TEST_URL=http://127.0.0.1:54321 \
   SUPABASE_TEST_ANON_KEY=... \
   SUPABASE_TEST_SERVICE_ROLE_KEY=... \
     flutter test test/integration --tags integration
   ```
   (Inside Docker per repo rules; the suite self-skips without the env
   vars.)

## Diagnosing "stuck" items in the field

An item that never reaches other devices is usually unsynced with a
permanently failing push (historically: a CHECK constraint rejected the
payload). Check: the sync status message reports "N change(s) could not be
uploaded"; `ErrorReporter` logs carry the per-item exception; on-device,
rows with `synced = false` and old `updated_at` are the stuck ones. The
age of the oldest unsynced row is the single best health metric.
