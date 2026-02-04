import 'dart:io';

import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Lightweight, fire-and-forget error reporter.
///
/// Sends caught and uncaught exceptions to the Supabase `error_logs`
/// table so that developers can inspect them via the dashboard.
/// Every code-path that calls [report] is completely safe: the method
/// is synchronous, never throws, and silently drops the event when
/// Supabase is not initialised or the network request fails.
class ErrorReporter {
  ErrorReporter._();

  /// Report an error.  [screen] identifies the feature area
  /// (e.g. `'sign_in'`, `'audio_player'`).
  static void report(
    Object error, {
    StackTrace? stackTrace,
    String? screen,
  }) {
    if (!SupabaseService.isInitialized) return;
    // ignore: unawaited_futures
    _insert(error, stackTrace, screen);
  }

  static Future<void> _insert(
    Object error,
    StackTrace? stackTrace,
    String? screen,
  ) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('error_logs').insert({
        'error_message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'screen': screen,
        'platform': _platform(),
      });
    } catch (_) {
      // Silently drop — reporting must never crash the app.
    }
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isLinux) return 'linux';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
    } catch (_) {
      // Platform throws on unsupported platforms; fall through.
    }
    return 'unknown';
  }
}
