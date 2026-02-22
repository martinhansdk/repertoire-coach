import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Controls device screen wake lock for mobile playback screens.
class ScreenAwakeService {
  ScreenAwakeService._();

  static bool get _supportsWakeLock {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!_supportsWakeLock) return;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on MissingPluginException {
      // Widget/unit tests may not register plugin channels.
    } on UnimplementedError {
      // Some runtimes may not implement wakelock.
    }
  }
}
