# Android Auto Bug Report

**File scope of investigation:**
- `lib/data/repositories/audio_player_repository_impl.dart`
- `lib/data/datasources/local/database.dart`
- `lib/data/datasources/local/database_connection_native.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/.../MainActivity.kt`
- `lib/presentation/providers/audio_player_provider.dart`
- `lib/main.dart`
- `pubspec.yaml`

---

## Bug 1 — CRITICAL (Browse): No error handling in `getChildren` / `_getFavoriteMediaItems`

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 438–495

```dart
@override
Future<List<MediaItem>> getChildren(String parentMediaId, [...]) async {
  if (parentMediaId == AudioService.browsableRootId) { ... }
  if (parentMediaId == _favoritesId) {
    return _getFavoriteMediaItems();   // ← can throw, no try-catch
  }
  return [];
}

Future<List<MediaItem>> _getFavoriteMediaItems() async {
  final userId = _userId;
  if (userId == null) return [];
  final favorites = await _database.getFavoriteTracks(userId); // ← can throw
  for (final fav in favorites) {
    final songRow = await _database.getSongById(trackRow.songId); // ← can throw
    ...
  }
}
```

Neither `getChildren` nor `_getFavoriteMediaItems` have any `try-catch`. If any database call throws — for example because the `favorite_tracks` table doesn't exist (see Bug 2), or a transient SQLite error — the exception propagates to `audio_service`'s native `onLoadChildren()` handler, which catches it internally and returns an empty result to Android Auto with no log and no retry. The car screen shows a blank browse list with no error visible to the developer.

**Fix:** Wrap `getChildren` in a `try-catch` that returns `[]` and calls `ErrorReporter.report()`. Wrap `_getFavoriteMediaItems` similarly.

---

## Bug 2 — CRITICAL (Browse): Database migration gaps leave `favorite_tracks` table missing on upgrade

**File:** `lib/data/datasources/local/database.dart`
**Lines:** 280–507

Drift's `onUpgrade(Migrator m, int from, int to)` is called **once** with the real `from`/`to` version numbers — it does not loop step-by-step. The migration strategy is written as a series of independent `if` statements, each requiring a specific single-step pair (e.g. `from == 8 && to == 9`). This only works if the user upgrades one version at a time.

For a user upgrading from schema v8 (or any older version) directly to v12, `from=8, to=12`. None of the sequential handlers match (`from == 8 && to == 9` requires `to == 9`). The only handler that fires is `if (from < 12 && to >= 12)`, which only adds the `markers_json` column to `marker_sets`. **It does not create the `favorite_tracks` table.**

```
Upgrade path v8 → v12 (from = 8, to = 12):

  ✗ from == 8 && to == 9    → doesn't fire (to ≠ 9): favorite_tracks table NOT created
  ✓ from < 12 && to >= 12   → fires: markers_json column added
  ✗ from == 9 && to == 10   → doesn't fire
  ✗ from == 10 && to == 11  → doesn't fire
```

Result: `favorite_tracks` doesn't exist. `getFavoriteTracks()` throws `"no such table: favorite_tracks"`. Combined with Bug 1 (no error handling), Android Auto silently shows an empty browse list.

**Additional note:** The handler for `from == 5 && to == 6` is entirely absent. If the app bumped the schema version from 5 to 6 for any reason, that upgrade path is silently skipped.

**Additional note:** The `from == 8 && to == 9` handler (which creates `favorite_tracks`) appears in source code **after** the `from < 12 && to >= 12` catch-all (line 440 vs 412). While Dart evaluates `if` statements in order, this is confusing and makes it visually appear that the catch-all would cover it — it won't.

**Fix:** Rewrite the migration using Drift's recommended step-by-step loop:

```dart
for (var step = from; step < to; step++) {
  switch (step) {
    case 1: // v1 → v2: add Choirs, ChoirMembers
      ...
    case 8: // v8 → v9: add FavoriteTracks
      await m.createTable(favoriteTracks);
      ...
  }
}
```

---

## Bug 3 — CRITICAL (Browse): Android Auto not notified after `AudioService.init()` completes

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 61–64, 74–77

```dart
// In constructor:
Future.microtask(() => _ensureInitialized());

// _initialize():
Future<void> _initialize() async {
  await _initializeAudioService();  // AudioService.init() runs here
  await _configureAudioSession();
  // ← nothing calls notifyChildrenChanged here
}
```

Android Auto may call `onGetRoot()` / `onLoadChildren()` at any time after the `MediaBrowserService` is bound. This can happen:
- When the user docks the phone in the car before opening the app (cold start via Android Auto)
- When Android Auto re-connects after a Bluetooth reconnect

In these cases, `getChildren()` is called on `_AudioPlayerHandler`. If this happens **before** `AudioService.init()` completes (while the microtask is still pending), there is no Dart handler registered yet, and `audio_service`'s native layer returns an empty result.

Even if initialization happens slightly after, Android Auto **caches** the browse tree result. It does not spontaneously re-query unless the service calls `notifyChildrenChanged()`. Since the code never calls this, the empty tree stays cached until the user manually exits and re-enters the media source on the car display.

**Fix:** After `_initializeAudioService()` completes, call:

```dart
AudioService.notifyChildrenChanged(AudioService.browsableRootId);
```

Also call `AudioService.notifyChildrenChanged(_favoritesId)` whenever the user adds or removes a favourite in the phone UI.

---

## Bug 4 — CRITICAL (Playback): `audioUrl` field ignored in `_playTrackById`

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 501–539

`_playTrackById` only checks `storagePath` (R2) and `filePath` (local):

```dart
String? signedUrl;
if (trackRow.storagePath != null) {
  try {
    signedUrl = await _signerClient.getPlayUrl(trackRow.id);
  } catch (_) {}
}

if (signedUrl != null) {
  await _player.setUrl(signedUrl);
} else if (trackRow.filePath != null) {
  await _player.setFilePath(trackRow.filePath!);
} else {
  return;  // ← silent no-op: nothing plays
}
```

The `Tracks` table has an `audioUrl` column (a public Supabase Storage URL) for tracks uploaded before the R2 migration. Any track that has `storagePath == null` and `filePath == null` but has a non-null `audioUrl` will silently fail to play from Android Auto. The `return` statement at line 526 is reached, no error is reported, and the car display shows the track as selected but doesn't play.

Compare with `AudioPlayerRepositoryImpl.playTrack()` at line 217, which correctly falls back to `track.audioUrl`:

```dart
final effectiveAudioUrl = audioUrl ?? track.audioUrl;  // ← uses audioUrl
```

This inconsistency means the same track that plays fine in the phone UI fails in Android Auto.

**Fix:** Add a fallback to `trackRow.audioUrl`:

```dart
final effectiveUrl = signedUrl ?? trackRow.audioUrl;
if (effectiveUrl != null) {
  await _player.setUrl(effectiveUrl);
} else if (trackRow.filePath != null) {
  ...
```

---

## Bug 5 — SIGNIFICANT (State): Android Auto playback leaves `AudioPlayerRepositoryImpl` state unsynced

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 501–539, 158–174, 329–344

When Android Auto triggers playback via `playFromMediaId()` → `_AudioPlayerHandler._playTrackById()`, that method:
- Starts the `just_audio` player ✓
- Updates `mediaItem` stream (notification) ✓
- Does **not** update `AudioPlayerRepositoryImpl._currentTrack`, `_currentSongName`, or `_currentAlbumName`

`AudioPlayerRepositoryImpl` still has `_currentTrack == null`. Consequences:

1. `_updatePlaybackInfo()` (called on every player state change) reads `_currentTrack` and broadcasts it as `null`, so the phone UI shows no active track even though audio is playing.

2. `_updateMediaItem()` (line 330) checks `if (_audioHandler == null || _currentTrack == null) return;`. It skips the update, so subsequent calls from the repository side (e.g. on duration change) silently do nothing.

3. If the user then switches playback from Android Auto to the phone UI, the UI starts in an inconsistent state.

**Fix:** `_AudioPlayerHandler._playTrackById()` needs to write back to the repository's state. The cleanest solution is to expose a callback or stream on `AudioPlayerRepositoryImpl` that `_AudioPlayerHandler` can call when Android Auto initiates playback.

---

## Bug 6 — MODERATE (Browse): N+1 queries may cause Android Auto browse timeout

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 463–495

`_getFavoriteMediaItems()` runs a separate SQL query **per favourite track** to fetch the song and concert:

```dart
for (final fav in favorites) {
  final trackRow = fav.track;
  final songRow = await _database.getSongById(trackRow.songId);   // +1 query
  if (songRow != null) {
    final concertRow = await _database.getConcertById(songRow.concertId);  // +1 query
    concertName = concertRow?.name;
  }
  items.add(...);
}
```

For a user with `n` favourites, this is `1 + 2n` sequential async round-trips to SQLite. Each hop also crosses the Dart/native boundary. Android Auto's `onLoadChildren()` callback has an internal timeout (typically 3–5 seconds depending on OEM). With 20+ favourites and a cold database (first access after boot), this may exceed the timeout, causing Android Auto to discard the response and show nothing.

**Fix:** Rewrite as a single join query that fetches tracks, songs, and concerts in one shot. The `Tracks`, `Songs`, and `Concerts` tables have the required foreign keys.

---

## Bug 7 — MINOR (Playback): `_AudioPlayerHandler.cleanup()` is never called

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Lines:** 690–693

```dart
/// Cleanup subscriptions
Future<void> cleanup() async {
  await _playerStateSubscription?.cancel();
  await _positionSubscription?.cancel();
}
```

This method is defined but never called from anywhere in the codebase. `AudioPlayerRepositoryImpl.dispose()` (line 394) cancels `_loopSubscription` but not the handler's subscriptions. The handler's `_playerStateSubscription` and `_positionSubscription` survive for the lifetime of the process, which is normally fine. However, if audio_service is ever re-initialised (which the `_initFuture ??=` guard prevents today but could change), a new handler would be created while old subscriptions fire, leading to double `_broadcastState()` calls.

**Fix:** Call `_handler.cleanup()` from `AudioPlayerRepositoryImpl.dispose()`, or make the cleanup implicit by cancelling subscriptions in `_AudioPlayerHandler`'s own `stop()` override.

---

## Bug 8 — MINOR (Config): Notification channel ID uses placeholder package name

**File:** `lib/data/repositories/audio_player_repository_impl.dart`
**Line:** 109

```dart
androidNotificationChannelId: 'com.example.repertoire_coach.audio',
```

The actual application package is `com.repertoirecoach.repertoire_coach` (visible in `MainActivity.kt`). The channel ID is a leftover from the Flutter project template. The channel ID doesn't need to match the package name for Android functionality, but it is visible in the system notification settings under the wrong name and makes it harder to identify the app's notification channels. On some OEM skins this can cause the channel to be miscategorised.

**Fix:** Change to `'com.repertoirecoach.repertoire_coach.audio'`.

---

## Summary Table

| # | Severity | Symptom | Root cause | Location |
|---|---|---|---|---|
| 1 | Critical | Favourites silently empty on any DB error | No try-catch in `getChildren` / `_getFavoriteMediaItems` | `audio_player_repository_impl.dart:438` |
| 2 | Critical | Favourites empty on upgrade from schema < v9 | Migration gaps: multi-version upgrades skip `favorite_tracks` creation | `database.dart:280` |
| 3 | Critical | Favourites empty on cold start via Android Auto | No `notifyChildrenChanged()` after `AudioService.init()` | `audio_player_repository_impl.dart:74` |
| 4 | Critical | Tracks with `audioUrl` (Supabase Storage) don't play | `audioUrl` field ignored in `_playTrackById` | `audio_player_repository_impl.dart:511` |
| 5 | Significant | Phone UI out of sync after Android Auto playback | `_currentTrack` not updated on Android Auto play | `audio_player_repository_impl.dart:501` |
| 6 | Moderate | Favourites empty for users with many tracks | N+1 queries may exceed Android Auto timeout | `audio_player_repository_impl.dart:463` |
| 7 | Minor | Memory leak if handler recreated | `cleanup()` never called | `audio_player_repository_impl.dart:690` |
| 8 | Minor | Wrong notification channel name in system settings | Template placeholder package name | `audio_player_repository_impl.dart:109` |

### Most likely cause of the reported "fails to present the favourites"

Bugs 1, 2, and 3 work together: if the device has an old schema (Bug 2), the database query throws an exception; Bug 1 lets that exception propagate silently; Bug 3 means Android Auto never re-queries after the handler becomes ready. Any one of these alone can produce a blank browse tree; all three together make it nearly certain to fail on any non-fresh-install scenario.
