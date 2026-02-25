import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/environment.dart';
import 'core/constants.dart';
import 'core/services/error_reporter.dart';
import 'core/services/supabase_service.dart';
import 'core/theme.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/screens/auth/auth_wrapper.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  // Wrap everything in runZonedGuarded so that:
  // 1. ensureInitialized and runApp are called from the same zone (required by Flutter)
  // 2. Uncaught async errors anywhere in startup or the app are reported
  runZonedGuarded(
    () async {
      // Ensure Flutter binding is initialized inside the zone
      WidgetsFlutterBinding.ensureInitialized();
      developer.log('Flutter bindings initialized', name: 'main');

      // Initialize Supabase if credentials are configured
      if (Environment.isSupabaseConfigured) {
        try {
          developer.log('Starting Supabase initialization...', name: 'main');
          await SupabaseService.initialize(
            url: Environment.supabaseUrl,
            anonKey: Environment.supabaseAnonKey,
          );
          developer.log('Supabase initialized successfully', name: 'main');
        } catch (e) {
          developer.log('Failed to initialize Supabase: $e', name: 'main', error: e);
          developer.log('App will run in offline-only mode', name: 'main');
        }
      } else {
        developer.log('Supabase credentials not configured - running in offline-only mode', name: 'main');
      }

      // Report uncaught Flutter framework errors (widget tree, layout, …)
      FlutterError.onError = (details) {
        ErrorReporter.report(
          details.exception,
          stackTrace: details.stack,
          screen: 'flutter_framework',
        );
      };

      developer.log('About to run app...', name: 'main');
      runApp(
        const ProviderScope(
          child: RepertoireCoachApp(),
        ),
      );
    },
    (error, stackTrace) {
      ErrorReporter.report(error, stackTrace: stackTrace, screen: 'async_zone');
    },
  );
}

/// Repertoire Coach Application
///
/// The root widget of the application, configured with theme
/// and bottom navigation between choirs and concerts.
class RepertoireCoachApp extends ConsumerWidget {
  const RepertoireCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Enable auto-sync when user signs in
    // This provider watches auth state and triggers sync from remote
    ref.watch(authSyncTriggerProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: SupabaseService.isInitialized
          ? const AuthWrapper() // Cloud-enabled mode
          : const HomeScreen(), // Offline-only mode
      debugShowCheckedModeBanner: false,
    );
  }
}
