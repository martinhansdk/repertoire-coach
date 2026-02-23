# Sync Bug Analysis

Identified during code review session (2026-02-22).
All bugs confirmed and fixed (2026-02-23).

---

## Bug 1 — Songs & Tracks Not Refreshed After Sync ✅ Fixed

**File:** `lib/presentation/providers/sync_provider.dart`

After a sync completes, `_refreshProviders()` was missing invalidations for
`songsByConcertProvider` and `tracksBySongProvider`. These are independent
`FutureProvider.family` instances and do not rebuild when parent providers
are invalidated.

**Fix (commit 2fed71f):** Added the two missing `ref.invalidate()` calls.

**Regression test:** `test/presentation/providers/sync_provider_test.dart`
— "regression: sync invalidates songsByConcertProvider and tracksBySongProvider"

---

## Bug 2 — `keepIds.isEmpty` Guard Prevents Remote-Delete Cleanup ✅ Fixed

**File:** `lib/data/datasources/local/database.dart`

Every `hardDeleteNotIn` method had an early-return guard `if (keepIds.isEmpty) return;`
that prevented cleanup when a user legitimately has no remote items for an entity
(e.g. removed from their last choir).

**Fix (commit 2fed71f):** Removed the guard from all five `hardDeleteNotIn` methods.

**Regression test:** `test/data/datasources/local/local_marker_data_source_test.dart`
— "regression: hardDeleteMarkerSetsNotIn with empty set deletes all synced records"

---

## Bug 3 — Push Failure Causes Local Changes to Be Overwritten ✅ Fixed

**File:** `lib/core/sync/sync_algorithm.dart`

If a push failed for an item, the pull phase found `syncedLocal[id] = null`
(item was unsynced) and called `upsertLocal(remoteItem)`, overwriting the user's
local changes with the older remote version.

**Fix (commit 2fed71f):** Added `failedPushIds` set. Items whose push fails are
added to it and skipped in the pull phase.

**Regression test:** `test/core/sync/sync_algorithm_test.dart`
— test #14: "regression: push failure does not overwrite local data with stale remote"

---

## Reported Bug — Marker Set Changes Reverted After Sync ✅ Fixed

**Root cause confirmed via logcat (2026-02-22):**

`RemoteMarkerDataSource.updateMarkerSet()` sent `markers_json` as a raw Dart
`String`. PostgREST stored it as a JSONB scalar string. The `marker_sets` CHECK
constraint (`jsonb_typeof(markers_json) = 'array'`) then rejected every update,
silently. Because both the direct push and the sync push failed, remote kept the
old `markers_json`. Bug 3 then caused the pull phase to overwrite local changes
with the stale remote data.

Note: `createMarkerSet` was not affected because it calls `markerSet.toJson()`
which correctly uses `jsonDecode(markersJson)`. Only the manually-built update
payload in `updateMarkerSet` was missing the decode step.

**Fix (commit 2fed71f):** Added `jsonDecode(markerSet.markersJson)` in
`RemoteMarkerDataSource.updateMarkerSet()` to match the behaviour of `toJson()`.

---

## Follow-up: ErrorReporter Wired Into All Catch Blocks ✅ Done

All repository catch blocks that previously used `print()` or `debugPrint()`
now call `ErrorReporter.report(e, stackTrace: st, screen: '...')`, which:
- `debugPrint()`s to logcat immediately (regardless of auth state)
- Inserts a row into the `error_logs` Supabase table (when authenticated)

Affected files (commits 139808e, 1f1a81d, and follow-up):
- `lib/data/repositories/marker_repository_impl.dart`
- `lib/data/repositories/auth_repository_impl.dart`
- `lib/data/repositories/choir_repository_impl.dart`
- `lib/data/repositories/concert_repository_impl.dart`
- `lib/data/repositories/song_repository_impl.dart`
- `lib/data/repositories/track_repository_impl.dart`
- `lib/core/sync/sync_algorithm.dart`

---

## Open Item: Dual Direct-Push Architecture

The repository pattern of writing locally then immediately pushing to remote
(bypassing the sync queue) is the root architectural tension that made these
bugs possible. The direct push creates a duplicate code path that can diverge
from the sync adapter path. Recommended future refactor: remove the eager
direct-push calls from repositories and instead trigger the sync algorithm
immediately after a local write.
