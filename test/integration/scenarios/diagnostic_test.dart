/// Diagnostic test to debug integration test issues
///
/// This is a minimal test to verify the app loads and we can see the UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  testWidgets(
    'diagnostic: app loads and shows UI',
    skip: true, // Requires Supabase - run manually
    (tester) async {
      debugPrint('=== DIAGNOSTIC TEST START ===');

      // Step 1: Initialize Supabase
      debugPrint('Step 1: Initializing test app...');
      await initializeTestApp();
      debugPrint('Supabase initialized successfully');

      // Step 2: Pump the app
      debugPrint('Step 2: Pumping app widget...');
      await pumpApp(tester);
      debugPrint('App widget pumped');

      // Step 3: Print what we see
      debugPrint('Step 3: Checking visible widgets...');

      // Print first 20 text widgets
      debugPrint('=== TEXT WIDGETS ===');
      final textWidgets = find.byType(Text).evaluate().take(20);
      for (final element in textWidgets) {
        final text = element.widget as Text;
        if (text.data != null && text.data!.isNotEmpty) {
          debugPrint('  Text: "${text.data}"');
        }
      }

      // Check for common screens
      final hasSignIn = find.text('Sign In').evaluate().isNotEmpty;
      final hasEmail = find.text('Email').evaluate().isNotEmpty;
      final hasPassword = find.text('Password').evaluate().isNotEmpty;
      final hasMyChoirs = find.text('My Choirs').evaluate().isNotEmpty;
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;

      debugPrint('=== SCREEN STATE ===');
      debugPrint('  Has "Sign In": $hasSignIn');
      debugPrint('  Has "Email": $hasEmail');
      debugPrint('  Has "Password": $hasPassword');
      debugPrint('  Has "My Choirs": $hasMyChoirs');
      debugPrint('  Has loading indicator: $hasLoading');

      if (hasSignIn && (hasEmail || hasPassword)) {
        debugPrint('RESULT: On sign-in screen');
      } else if (hasMyChoirs) {
        debugPrint('RESULT: On home screen (already signed in)');
      } else if (hasLoading) {
        debugPrint('RESULT: Still loading...');
      } else {
        debugPrint('RESULT: Unknown screen state');
      }

      // If we got here, the test didn't hang
      debugPrint('=== DIAGNOSTIC TEST COMPLETE ===');
      expect(true, isTrue); // Always pass if we get here
    },
  );

  testWidgets(
    'diagnostic: can find and interact with text fields',
    skip: true, // Enable after first test passes
    (tester) async {
      await initializeTestApp();
      await pumpApp(tester);

      // Try to find text fields
      debugPrint('Looking for TextFormField widgets...');
      final textFormFields = find.byType(TextFormField).evaluate();
      debugPrint('Found ${textFormFields.length} TextFormField widgets');

      debugPrint('Looking for TextField widgets...');
      final textFields = find.byType(TextField).evaluate();
      debugPrint('Found ${textFields.length} TextField widgets');

      // Try to find by predicate
      debugPrint('Looking for any editable text widgets...');
      final editableTexts = find.byType(EditableText).evaluate();
      debugPrint('Found ${editableTexts.length} EditableText widgets');

      expect(true, isTrue);
    },
  );
}
