/// Minimal test to verify Supabase initialization works in Docker
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';

void main() {
  testWidgets('Supabase initializes successfully', skip: true, (tester) async {
    debugPrint('=== Supabase Init Test ===');

    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Step 1: Bindings initialized');

    const url = 'https://riotwqypcjzxgzybxdwo.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpb3R3cXlwY2p6eGd6eWJ4ZHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5MDA0NTAsImV4cCI6MjA4MTQ3NjQ1MH0.WCYrCuHVhcJ1ZfwmdW-rvXgUVk3aTDQJmh2hO1IeAco';

    debugPrint('Step 2: About to initialize Supabase...');

    if (!SupabaseService.isInitialized) {
      await SupabaseService.initialize(url: url, anonKey: anonKey);
    }

    debugPrint('Step 3: Supabase initialized!');
    debugPrint('Is initialized: ${SupabaseService.isInitialized}');

    expect(SupabaseService.isInitialized, isTrue);
    debugPrint('=== Test Complete ===');
  });
}
