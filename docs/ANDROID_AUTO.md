# Android Auto Support

This document describes how Android Auto integration works in Repertoire Coach.

## Overview

Android Auto support is implemented via the `audio_service` Flutter package, which registers a `MediaBrowserService` and `MediaSession` on Android. There is **no custom Java/Kotlin** for the Auto integration beyond engine pre-caching in `MainActivity`. Users can browse their favourite tracks from the car display and control playback from the steering wheel.

## Architecture

```
Android Auto (car display)
        │  MediaBrowserService / MediaSession
        ▼
audio_service package  ←──── platform channel ────►  _AudioPlayerHandler (Dart)
        │                                                      │
        │  just_audio                                   Drift SQLite DB
        ▼                                               (local cache)
  Audio Decoder                                               │
        │                                             Supabase / R2 (audio files)
        ▼
  Car / Notification speaker
```

## Native Android Layer

### `android/app/src/main/AndroidManifest.xml`

| Declaration | Detail |
|---|---|
| `com.ryanheise.audioservice.AudioService` | Exported `MediaBrowserService`; Android Auto discovers this |
| `BIND_MEDIA_BROWSER_SERVICE` permission | Required for Auto to bind to the service |
| `com.ryanheise.audioservice.MediaButtonReceiver` | Routes hardware media button events (headset, steering wheel) |
| `com.google.android.gms.car.application` meta-data | Points to `automotive_app_desc.xml` |

Required permissions: `INTERNET`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `READ_MEDIA_AUDIO`.

### `android/app/src/main/res/xml/automotive_app_desc.xml`

```xml
<automotiveApp>
    <uses name="media"/>
</automotiveApp>
```

Declares this as a media app so Android Auto includes it in the media source list.

### `android/app/src/main/kotlin/.../MainActivity.kt`

Overrides `provideFlutterEngine()` to pre-cache the Flutter engine under the key `"audio_service_engine"`. This is critical: `audio_service` requires the engine to exist before Android Auto's background service discovery runs at boot. Without it, a second engine is created, triggering assertion failures and breaking `MediaSession` registration.

## Flutter Layer

### Primary file: `lib/data/repositories/audio_player_repository_impl.dart`

All Android Auto logic lives here. There are two classes:

#### `AudioPlayerRepositoryImpl`

Manages lifecycle and initialisation:

- **Lazy init**: `AudioService.init()` is deferred to first playback, but a `Future.microtask(() => _ensureInitialized())` in the constructor ensures Android Auto can discover the service at startup before any playback occurs.
- **Audio session**: Configured with category `playback` (continues in background), ducking enabled, Android audio attributes set to `music / media / gain`.
- **Audio offload disabled**: The `just_audio` player is created with `androidAudioOffloadMode: disabled`. Offload mode hands the decoder to the hardware DSP which loses its connection when the screen locks, silently killing playback after ~60 seconds.

#### `_AudioPlayerHandler`

Extends `BaseAudioHandler` (from `audio_service`). This base class handles all `MediaBrowserService` and `MediaSession` plumbing via a platform channel. Key dependencies:

| Field | Type | Purpose |
|---|---|---|
| `_player` | `just_audio.AudioPlayer` | Audio decoding and streaming |
| `_database` | Drift DB | Local cache of tracks / songs / concerts / favourites |
| `_supabaseService` | SupabaseService | Auth (current user ID) |
| `_signerClient` | R2SignerClient | Generates presigned R2 playback URLs |

## Browse Tree

Android Auto calls `getChildren(parentMediaId)` to build its browse UI.

```
AudioService.browsableRootId  (system root)
└── Favourites  (browsable folder, not playable)
    ├── "Amazing Grace – Soprano"   album: "Easter Concert 2025"
    ├── "Hallelujah – Alto"         album: "Christmas Concert 2024"
    └── ...
```

- **Root**: returns a single "Favourites" `MediaItem` (not playable, browsable).
- **Favourites**: queries `_database.getFavoriteTracks(userId)`, joins with `tracks`, `songs`, and `concerts` tables in the local Drift SQLite cache, and returns one `MediaItem` per favourite with:
  - `id`: track UUID
  - `title`: `"${song.title} – ${track.name}"` (e.g. "Hallelujah – Soprano")
  - `album`: concert name
  - `duration`: track duration in milliseconds
  - `playable`: true

Only one browse level is currently implemented. The directory `lib/platform/android_auto/` exists for a planned concert-hierarchy browse tree but is empty.

## Playback Flow

When Android Auto selects a track (`playFromMediaId` / `playMediaItem`):

1. Look up the track row in the local Drift DB (`_database.getTrackById(trackId)`).
2. Request a presigned R2 URL from `_signerClient.getPlayUrl(trackId)` (calls the `audio-signer` Supabase Edge Function).
3. Fall back to `trackRow.filePath` (local file) if R2 is unavailable.
4. `_player.setUrl(url)` → `_player.play()`.
5. Push updated `mediaItem` (notification metadata) and call `_broadcastState()`.

## Playback Controls

`_broadcastState()` pushes a `PlaybackState` to `audio_service`, which updates both the Android Auto display and the phone lock screen:

| Control | Action |
|---|---|
| Rewind | Seek back 10 s (or to 0) |
| Play / Pause | Toggle playback |
| Fast Forward | Seek forward 10 s (or to end) |
| Seek | Scrub to any position |
| Stop | Stop and dismiss notification |

## Voice Search

`search(query)` is implemented: filters all favourites where `title` or `album` contains the query string. Enables "Hey Google, play Hallelujah" from the car.

## Authentication

Uses `_supabaseService.client.auth.currentUser?.id` at query time. Android Auto only exposes the signed-in user's favourites. If no user is logged in, the browse tree is empty.

## Package Stack

| Package | Version | Role |
|---|---|---|
| `audio_service` | ^0.18.17 | `MediaBrowserService` + `MediaSession` via platform channel |
| `just_audio` | ^0.10.5 | Audio decoding and streaming |
| `audio_session` | ^0.1.21 | Audio focus, ducking, background playback category |
| `drift` | ^2.29.0 | Local SQLite cache of tracks / songs / concerts / favourites |

## Known Limitations & Future Work

- **Single browse level**: only "Favourites" is exposed; a concert → song → track hierarchy is planned (`lib/platform/android_auto/` is reserved for this).
- **No album art**: `artUri` is null on all `MediaItem`s.
- **Favourites only**: the full concert/song library is not browsable from the car.
