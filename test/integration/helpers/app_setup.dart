/// App setup helpers for integration tests
///
/// Provides utilities to set up the app for integration testing,
/// including provider overrides and test environment configuration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/main.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';

/// Initialize the app for integration testing
///
/// This sets up Supabase and other services needed for the app to function.
/// Call this once at the start of your test.
Future<void> initializeTestApp() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if not already initialized
  if (!SupabaseService.isInitialized) {
    // Use environment variables or hardcoded test values
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ndqkdnjgvmigleczcvqx.supabase.co',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kcWtkbmpndm1pZ2xlY3pjdnF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU3MTk0NzcsImV4cCI6MjA1MTI5NTQ3N30.WGqNmh2_bQbILxqvkrmXoCA3r6_Hf-N2AgAQH8i3VrQ',
    );

    await SupabaseService.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// Pump the app widget for testing
///
/// Creates a ProviderScope with the app and pumps it.
/// Uses explicit duration pumps instead of pumpAndSettle to avoid
/// timeout issues with streams that never complete.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: RepertoireCoachApp(),
    ),
  );

  // Pump for a fixed duration to allow initial load
  // Don't use pumpAndSettle - it will timeout with ongoing streams
  await tester.pump(const Duration(seconds: 3));
}

/// A test wrapper that initializes the app and handles cleanup
///
/// Usage:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await runIntegrationTest(tester, () async {
///     // Your test code here
///   });
/// });
/// ```
Future<void> runIntegrationTest(
  WidgetTester tester,
  Future<void> Function() testBody,
) async {
  await initializeTestApp();
  await pumpApp(tester);
  await testBody();
}

/// Debug helper: Print current screen state
void debugPrintScreenState(WidgetTester tester) {
  debugPrint('=== CURRENT SCREEN STATE ===');

  // Check for common screens
  if (find.text('Sign In').evaluate().isNotEmpty) {
    debugPrint('Screen: Sign In');
  } else if (find.text('My Choirs').evaluate().isNotEmpty) {
    debugPrint('Screen: Choir List (Home)');
  } else if (find.text('Concerts').evaluate().isNotEmpty) {
    debugPrint('Screen: Choir Detail');
  } else if (find.text('Songs').evaluate().isNotEmpty) {
    debugPrint('Screen: Concert Detail');
  } else if (find.byIcon(Icons.play_circle_filled).evaluate().isNotEmpty ||
      find.byIcon(Icons.pause_circle_filled).evaluate().isNotEmpty) {
    debugPrint('Screen: Audio Player');
  } else {
    debugPrint('Screen: Unknown');
  }

  // Print visible text
  debugPrint('Visible text:');
  final textWidgets = find.byType(Text).evaluate().take(10);
  for (final element in textWidgets) {
    final text = element.widget as Text;
    if (text.data != null && text.data!.isNotEmpty) {
      debugPrint('  - ${text.data}');
    }
  }

  debugPrint('============================');
}
