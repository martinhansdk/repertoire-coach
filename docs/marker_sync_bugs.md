# Marker Sync Bugs — TODO

Identified in session 2026-02-24. Work through in order: write failing test → fix → tests pass → commit → next.

---

## 1. Jump-back + re-sync wipes too much [ ]

**File:** `lib/presentation/providers/marker_sync_provider.dart` — `syncNextMarker()`

**Problem:**
When the user taps an earlier marker in the list (`jumpToMarker` moves `currentIndex` back) and
then presses "Mark Here", `syncNextMarker` detects `currentIndex < lastSyncedIndex` and calls:

```dart
newPositions.removeWhere((key, _) => key > state.currentIndex);
```

This clears ALL synced positions after `currentIndex`, even ones that are perfectly consistent
with the new sync point. Syncing a song is a lot of work; the user may just want to fix one
section without re-doing everything after it.

**Desired behaviour:**
Accept the new position and *cascade-invalidate* only the minimum number of following markers
needed to restore monotonicity:

- Starting from `syncIndex + 1`, remove each entry whose position < new position.
- Stop as soon as an entry with position ≥ new position is found — that one and everything
  after it are already consistent and must be left alone.

If the new position itself would be less than the nearest preceding synced position (impossible
to satisfy monotonicity without going back further), **reject** the sync silently (same
behaviour as `nudgeSyncedPosition`).

**Test file:** `test/presentation/providers/marker_sync_provider_test.dart`

**Tests to write:**
- Jump back, re-sync within bounds → only inconsistent followers invalidated, rest preserved.
- Jump back, re-sync exactly at preceding position → accepted, nothing invalidated.
- Jump back, re-sync at value that would overtake several followers → cascade clears only
  those, first consistent follower survives.
- Jump back, re-sync at position < previous synced marker → rejected, state unchanged.
- Normal sequential sync (no jump) → no change in behaviour.

---

## 2. `_syncMarkerSetPayload` sends stale `is_time_synced` [ ]

**File:** `lib/data/repositories/marker_repository_impl.dart` — `_syncMarkerSetPayload()`

**Problem:**
`replaceMarkersByMarkerSet` updates `markers_json` in the local DB, then calls
`_syncMarkerSetPayload`. That method reads the local marker-set record — `markers_json` is
fresh, but `is_time_synced` is the **stale** DB value (may be `false` from an earlier
`startSyncFromText` text-change path). Supabase's check constraint
`marker_sets_is_time_synced_matches_payload` requires these two columns to agree, so the
remote update fails with a constraint violation.

**Error seen in production:**
```
Failed to update marker set in Supabase:
new row for relation "marker_sets" violates check constraint
"marker_sets_is_time_synced_matches_payload"
```

**Fix:**
In `_syncMarkerSetPayload`, compute the correct `isTimeSynced` value from the `markers_json`
payload (same logic as the DB function: `true` iff every non-empty label has a non-null
`positionMs`) instead of trusting the stale DB field.

**Test file:** `test/data/repositories/marker_repository_impl_test.dart`

**Tests to write:**
- `replaceMarkersByMarkerSet` called when local `is_time_synced = false` but all markers have
  positions → remote `updateMarkerSet` is called with `is_time_synced: true`.
- `replaceMarkersByMarkerSet` called when some non-empty markers lack positions → remote
  `updateMarkerSet` called with `is_time_synced: false`.
- `replaceMarkersByMarkerSet` called when local `is_time_synced = true` and all markers have
  positions → remote `updateMarkerSet` called with `is_time_synced: true` (no regression).

---

## 3. "ref after disposed" in `_scrollToCurrentMarker` [ ]

**File:** `lib/presentation/screens/marker_sync/time_sync_step.dart` — `_scrollToCurrentMarker()`

**Problem:**
`_scrollToCurrentMarker` is scheduled via `addPostFrameCallback` inside the `ref.listen`
callback. After `save()` completes and `Navigator.pop` is called the widget is disposed, but
the pending callback fires and calls `ref.read(...)` before checking `mounted`:

```dart
void _scrollToCurrentMarker() {
  final state = ref.read(markerSyncNotifierProvider(widget.params)); // ← crashes
  if (!mounted) return;
  ...
}
```

**Error seen in production:**
```
Bad state: Cannot use "ref" after the widget was disposed.
```

**Fix:**
Move the `if (!mounted) return;` guard to the **first line** of `_scrollToCurrentMarker`,
before any `ref` access.

**Test file:** `test/presentation/screens/marker_sync/time_sync_step_test.dart`

**Tests to write:**
- Simulate save completing (state changes) followed by widget disposal; verify no exception
  is thrown from the postFrameCallback (i.e. the `mounted` guard fires first).

---

## 4. No sync trigger on web (pull-to-refresh not available) [ ]

**Problem:**
The only manual sync trigger is pull-to-refresh, which is a mobile gesture unavailable on web.
Users on web never get fresh data from other choir members unless they sign out and back in.

**Fix:**
Trigger `syncFromRemote()` when the user navigates **to** key screens. Use the existing
`syncControllerProvider`; only trigger when `SyncStatus.idle` or `SyncStatus.success` (not
while a sync is already in progress, and not on error to avoid hammering a broken connection).

Screens to add on-enter sync:
- `choir_list_screen.dart` (already has manual sync — replace / supplement)
- `song_list_screen.dart`
- `song_detail_screen.dart`
- `marker_manager_screen.dart`

Implementation: override `initState` (or use a `ref.listen` on a navigation-triggered
provider) to call `syncFromRemote()` once per screen visit.

**Test file:** `test/presentation/screens/` (widget tests for affected screens)

**Tests to write:**
- Navigating to each screen triggers `syncFromRemote()` when status is idle.
- Does NOT trigger when sync is already in progress.
- Does NOT trigger when status is error (to avoid hammering).

---

## Status legend
- `[ ]` not started
- `[~]` in progress
- `[x]` done and committed
