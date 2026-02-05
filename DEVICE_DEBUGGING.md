# Android Device Debugging

How to debug issues that only reproduce on a physical device — particularly
audio / background-playback problems that cannot be caught by unit tests or the
web dev server.

## Prerequisites

* A physical Android device with **USB debugging enabled** (`Settings →
  Developer Options → USB Debugging`).
* `adb` on the host (`PATH`).  Usually comes with the Android SDK
  Platform-Tools.
* A build to deploy (CI artifact or local `flutter build apk`).

## Deploy → Capture → Reproduce → Analyse

### 1. Deploy

```bash
# From a CI run (interactive menu picks the latest)
./scripts/deploy.py

# Or install an APK directly
adb install -r path/to/app.apk
```

### 2. Start logcat capture *before* launching the app

```bash
# Clear the buffer first (run this as its own command; do NOT chain with &&
# because logcat -c can hang in a pipeline).
adb logcat -c

# Then start capturing to a file.  -v threadtime gives PID/TID which is
# essential for correlating Flutter engine threads.
adb logcat -v threadtime > /tmp/device.log
# leave this running in its own terminal
```

> **Gotcha:** `adb logcat -c && adb logcat` can hang — `logcat -c` does not
> always exit cleanly when chained.  Run them as two separate commands.

### 3. Reproduce the issue on the device

Open the app, perform the action that triggers the bug, wait long enough for
the failure to manifest (e.g. lock the screen and wait 90 seconds for
background-audio kills).

### 4. Stop capture and analyse

Press `Ctrl-C` in the logcat terminal, then filter:

```bash
# Everything from our package (broad first pass)
grep "repertoire_coach" /tmp/device.log > /tmp/filtered.log

# Or targeted — see "What to search for" below
grep -n "FlutterEngineCxnRegstry\|flutter :\|MediaSession\|PARTIAL_WAKE\|Killing\|freezeState\|AudioService" /tmp/device.log
```

If you only need a snapshot of what's in the buffer *right now* without a
running capture, `adb logcat -d` dumps the current ring buffer and exits.

---

## What to search for

### App lifecycle

| Pattern | Meaning |
|---|---|
| `ActivityManager: Start proc …com.repertoirecoach` | Cold start of the app process |
| `ActivityManager: Killing …com.repertoirecoach … (adj …)` | Process killed.  The reason is at the end: `remove task` = user swiped, `stop … due to installPackageLI` = new APK installed, others are system-initiated kills |
| `ActivityManager: Killing … (adj 850)` | adj 850 = cached/stopped.  Normal for user-swiped kills |
| `ActivityManager: Killing … (adj 1001)` | adj 1001 = service being stopped.  Abnormal for a foreground-service app |

### audio_service / Flutter engine

| Pattern | Meaning |
|---|---|
| `FlutterEngineCxnRegstry: Attempted to register plugin … already registered` | Expected with `provideFlutterEngine`.  Flutter registers plugins in `setUpFlutterEngine`; any subsequent `registerWith` call is a harmless no-op warning.  If this warning disappears, something changed in the lifecycle — investigate. |
| `flutter : … AudioService.init …` | Our Dart-side debug output (remove before shipping; see below) |
| `PlatformException … Activity class … wrong … FlutterEngine` | `wrongEngineDetected` in audio_service.  The main app's engine is not in `FlutterEngineCache` under key `"audio_service_engine"`.  See "The FlutterEngineCache story" below. |
| `Failed assertion: '!androidNotificationOngoing \|\| androidStopForegroundOnPause'` | `AudioServiceConfig` has `androidNotificationOngoing: true` but `androidStopForegroundOnPause: false`.  These two flags are mutually inconsistent. |

### Background playback health

| Pattern | Meaning |
|---|---|
| `MediaSessionService: Media button session is changed to …repertoire_coach` | The system recognises our app as the active media player.  Must appear before playback starts. |
| `PARTIAL_WAKE_LOCK … 'com.ryanheise.audioservice.AudioService' ACQ=-Xs` | The audio_service foreground service is holding a wake lock.  The `ACQ` time grows as long as the service is alive.  If it stops growing or disappears, the foreground service died. |
| `MediaTimeout: processState … state=3` | `state=3` = STATE_PLAYING.  Position should tick up every ~200 ms.  If it freezes, playback stopped at the hardware level. |
| `AS.AudioService: uid:…is using audio` | The Android audio subsystem confirms our UID has an active audio stream.  Appears every ~15 s while playing. |
| `onFreezeStateChanged` / `freezeStateChanged` | Samsung-specific.  The process manager froze (or unfroze) a process.  If this fires for our package while audio is supposed to be playing, the foreground service failed to keep the process alive. |
| `Notification … channel=com.example.repertoire_coach.audio … actions=3` | The media notification was posted with 3 action buttons (rewind, play/pause, fast-forward). |

### Healthy run — expected sequence

```
1. ActivityManager: Start proc … com.repertoirecoach   ← cold start
2. FlutterEngineCxnRegstry: … already registered       ← expected, harmless
3. MediaSessionService: … session is changed            ← system sees us
4. AudioService.init … SUCCESS                          ← foreground service up
5. Notification … channel=…audio … actions=3            ← notification posted
6. PARTIAL_WAKE_LOCK … ACQ= growing                    ← wake lock alive
7. MediaTimeout … state=3 … position ticking            ← audio playing
8. AS.AudioService: uid … is using audio                ← stream confirmed
   (repeat 6-8 for the duration of playback)
9. ActivityManager: Killing … remove task               ← user swiped (clean)
```

If step 4 says FAILED, everything after it breaks: no foreground service, no
wake lock, no notification → the system kills the app within ~60 seconds on
Samsung.

---

## The FlutterEngineCache story

`audio_service` needs to run a background `Service` that shares the same
Flutter engine as the main Activity.  It looks up the engine from
`FlutterEngineCache` under the static key `"audio_service_engine"`.

The Flutter `FlutterActivity` delegate calls lifecycle hooks in this order:

```
1. setUpFlutterEngine()
     └── provideFlutterEngine()   ← OUR HOOK: create engine + put in cache
     └── registerWith(engine)     ← Flutter registers plugins here
2. attachToActivity()
     └── onAttachedToActivity()   ← audio_service checks the cache HERE
3. (platform channels)
4. configureFlutterEngine()       ← TOO LATE to populate the cache
```

`configureFlutterEngine` (step 4) was the first hook tried.  It compiled and
CI passed, but failed at runtime: `onAttachedToActivity` (step 2) had already
run and set `wrongEngineDetected = true` because the cache was empty.

`provideFlutterEngine` (step 1) is the earliest possible hook.  Creating and
caching the engine there ensures `onAttachedToActivity` finds it.

Because Flutter already calls `GeneratedPluginRegistrant.registerWith()` in
step 1, there is no need to call it again in `configureFlutterEngine` — doing
so produces the harmless "already registered" warning.

### If you see `wrongEngineDetected` again

1. Confirm `provideFlutterEngine` in `MainActivity.kt` creates the engine
   **and** puts it in the cache before returning.
2. Confirm the cache key is exactly `"audio_service_engine"` (no typo).
3. Confirm you are not accidentally creating a second `FlutterEngine`
   somewhere else in the app.

---

## Adding temporary debug prints

When you need visibility into what's happening on-device, add prints in Dart:

```dart
// ignore: avoid_print
print('DEBUG myFunction: someValue=$someValue');
```

These appear in logcat as:
```
… I flutter : DEBUG myFunction: someValue=…
```

Filter with: `grep "flutter :" /tmp/device.log`

**Always remove debug prints before merging.**  The `// ignore: avoid_print`
comment suppresses the lint but is a signal that the line is temporary.

---

## Samsung-specific behaviour

Samsung devices run a process manager that **freezes** background processes
after the screen locks, regardless of wake locks, unless a foreground service
is active.  The freeze typically fires ~60 seconds after screen-off.

* If you see `onFreezeStateChanged` for our package, the foreground service
  is not running (or not running as `mediaPlayback`).
* Confirm `AndroidManifest.xml` declares the service with
  `foregroundServiceType="mediaPlayback"` and the app has the
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission.
* Confirm `AudioService.init()` actually succeeds (check the log — if it
  threw, the foreground service was never started).

---

## Quick-reference commands

```bash
# Deploy latest CI build
./scripts/deploy.py

# Clear logcat buffer (run alone, not chained)
adb logcat -c

# Capture with timestamps and thread IDs
adb logcat -v threadtime > /tmp/device.log

# Dump current buffer and exit (no ongoing capture needed)
adb logcat -d > /tmp/device.log

# Filter to our package
grep "repertoire_coach" /tmp/device.log

# Key audio-lifecycle events only
grep -n "FlutterEngineCxnRegstry\|flutter :\|MediaSessionService\|PARTIAL_WAKE\|Killing\|freezeState\|AudioService\|MediaTimeout" /tmp/device.log

# Check if device is connected
adb devices
```
