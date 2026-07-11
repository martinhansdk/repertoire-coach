---
name: device-debugging
description: >
  Debug issues that only reproduce on a physical Android device — especially
  audio and background-playback problems that unit tests and the web dev
  server cannot catch. Use when: background audio dies after screen lock
  (~60-90s, especially Samsung), the media notification is missing, logcat
  shows "wrongEngineDetected" / "PlatformException ... wrong FlutterEngine",
  "Failed assertion: '!androidNotificationOngoing ||
  androidStopForegroundOnPause'", "onFreezeStateChanged" for our package, or
  ActivityManager kills the app unexpectedly. Also use for any task
  requiring adb logcat capture or analysis of a device log.
---

# Android Device Debugging

Workflow: **Deploy → Capture → Reproduce → Analyse.** The capture and
analysis steps are scripted; the knowledge tables below are for interpreting
what the analyser flags.

## Procedure

1. **Deploy** a build: `./scripts/deploy.py` (interactive; picks latest CI
   build) or `adb install -r path/to/app.apk`. Preflight: `adb devices`.
2. **Capture** — start BEFORE launching the app:
   `bash .claude/skills/device-debugging/scripts/capture.sh`
   Writes `logs/device-<timestamp>.log`; Ctrl-C to stop. (Handles the
   gotcha that `adb logcat -c && adb logcat` hangs — the buffer clear must
   run as its own command.) For a snapshot of the current buffer without an
   ongoing capture: `capture.sh --dump`.
3. **Reproduce** on the device. For background-audio bugs: start playback,
   lock the screen, wait ≥90 seconds (Samsung's process freezer fires ~60s
   after screen-off).
4. **Analyse**:
   `bash .claude/skills/device-debugging/scripts/analyze_log.sh logs/device-<ts>.log`
   Checks the healthy-run sequence, reports which steps are missing, and
   flags kill reasons, freeze events, and known error signatures. Interpret
   findings with the tables below.

## Healthy run — expected sequence

1. `ActivityManager: Start proc … com.repertoirecoach` — cold start
2. `FlutterEngineCxnRegstry: … already registered` — expected, harmless
3. `MediaSessionService: … session is changed` — system sees us as the player
4. `AudioService.init … SUCCESS` — foreground service up
5. `Notification … channel=…audio … actions=3` — media notification posted
6. `PARTIAL_WAKE_LOCK … ACQ=` growing — wake lock alive
7. `MediaTimeout … state=3`, position ticking — audio playing
8. `AS.AudioService: uid … is using audio` — stream confirmed (~15s cadence)
9. `ActivityManager: Killing … remove task` — user swiped (clean exit)

If step 4 says FAILED, everything after it breaks: no foreground service, no
wake lock, no notification — Samsung kills the app within ~60 seconds.

## Interpreting signatures

**Lifecycle / kills:** `Killing … remove task` = user swipe (normal);
`… due to installPackageLI` = new APK installed; `adj 850` = cached/stopped
(normal for swipes); `adj 1001` = a service being stopped — ABNORMAL for a
foreground-service app.

**audio_service / engine:**
- `already registered` warning is *expected* with `provideFlutterEngine`
  (plugins register in `setUpFlutterEngine`; later `registerWith` is a
  no-op). If this warning DISAPPEARS, the lifecycle changed — investigate.
- `wrongEngineDetected` / `PlatformException … wrong FlutterEngine`: the
  main engine is not in `FlutterEngineCache` under the exact key
  `"audio_service_engine"`. See the engine-cache story below.
- `Failed assertion: '!androidNotificationOngoing ||
  androidStopForegroundOnPause'`: those two `AudioServiceConfig` flags are
  mutually inconsistent (`ongoing: true` requires
  `stopForegroundOnPause: true`).

**Samsung freezer:** `onFreezeStateChanged` for our package while audio
should be playing means the foreground service is not running (or not as
`mediaPlayback`). Check: manifest declares
`foregroundServiceType="mediaPlayback"`, the
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission exists, and `AudioService
.init()` actually succeeded in the log.

## The FlutterEngineCache story

`audio_service` runs a background Service sharing the main Activity's Flutter
engine, looked up from `FlutterEngineCache` under `"audio_service_engine"`.
FlutterActivity's hook order:

```
1. setUpFlutterEngine()
     → provideFlutterEngine()   ← OUR HOOK: create engine + put in cache
     → registerWith(engine)       (Flutter registers plugins here)
2. attachToActivity()
     → onAttachedToActivity()   ← audio_service checks the cache HERE
3. (platform channels)
4. configureFlutterEngine()     ← TOO LATE to populate the cache
```

`configureFlutterEngine` (4) compiles and passes CI but fails at runtime:
`onAttachedToActivity` (2) has already set `wrongEngineDetected` on an empty
cache. The engine MUST be created and cached in `provideFlutterEngine` (1),
in `MainActivity.kt`. Do not call `GeneratedPluginRegistrant.registerWith()`
again in `configureFlutterEngine` — Flutter already did it in step 1.

If `wrongEngineDetected` reappears: (a) `provideFlutterEngine` creates AND
caches before returning, (b) cache key is exactly `"audio_service_engine"`,
(c) no second `FlutterEngine` is created elsewhere.

## Temporary debug prints

```dart
// ignore: avoid_print
print('DEBUG myFunction: someValue=$someValue');
```
Appears in logcat as `I flutter : DEBUG …`; filter with
`grep "flutter :"`. The `// ignore: avoid_print` marks the line as
temporary — **always remove debug prints before merging.**
