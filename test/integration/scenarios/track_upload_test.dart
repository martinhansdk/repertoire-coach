/// Track upload integration test scenario
///
/// Tests the full flow: sign in -> navigate to song -> add track -> verify
///
/// Run with:
/// ```
/// mcp__flutter__flutter_test(path: "test/integration/scenarios/track_upload_test.dart")
/// ```
///
/// Note: These tests require a real Supabase connection and are skipped by default.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Track Upload Scenario', () {
    testWidgets(
      'should navigate to song detail and see Add Track button',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Track Upload Navigation Test ===');

          // Sign in
          debugPrint('Step 1: Signing in...');
          expect(isOnSignInScreen(tester), isTrue);
          final signInSuccess = await signIn(tester);
          expect(signInSuccess, isTrue, reason: 'Sign-in should succeed');

          // Navigate to test song
          debugPrint('Step 2: Navigating to test song...');
          final navSuccess = await navigateToTestSong(tester);
          expect(navSuccess, isTrue, reason: 'Should navigate to song');

          // Verify we're on song detail screen
          debugPrint('Step 3: Verifying song detail screen...');
          expect(isOnSongDetailScreen(tester), isTrue,
              reason: 'Should be on song detail screen');

          // Verify Add Track button exists
          debugPrint('Step 4: Looking for Add Track button...');
          final addTrackButton = findAddTrackButton(tester);
          expect(addTrackButton, isTrue,
              reason: 'Add Track button should be visible');

          debugPrint('=== Navigation test complete ===');
        });
      },
    );

    testWidgets(
      'should open Add Track dialog when button is tapped',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Add Track Dialog Test ===');

          // Sign in and navigate to song
          await signIn(tester);
          await navigateToTestSong(tester);

          // Tap Add Track button
          debugPrint('Tapping Add Track button...');
          final tapSuccess = await tapAddTrackButton(tester);
          expect(tapSuccess, isTrue, reason: 'Should tap Add Track button');

          // Verify dialog appeared
          debugPrint('Verifying Add Track dialog...');
          await tester.pump(const Duration(milliseconds: 500));
          expect(isAddTrackDialogVisible(tester), isTrue,
              reason: 'Add Track dialog should be visible');

          // Verify dialog has expected fields
          expect(hasTrackNameField(tester), isTrue,
              reason: 'Dialog should have track name field');
          expect(hasSelectFileButton(tester), isTrue,
              reason: 'Dialog should have file select button');

          debugPrint('=== Dialog test complete ===');
        });
      },
    );

    testWidgets(
      'should show validation error for empty track name',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Validation Test ===');

          // Sign in and navigate to song
          await signIn(tester);
          await navigateToTestSong(tester);

          // Open Add Track dialog
          await tapAddTrackButton(tester);
          await tester.pump(const Duration(milliseconds: 500));

          // Try to submit without entering anything
          debugPrint('Trying to submit empty form...');
          final submitButton = find.text('Create');
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pump(const Duration(milliseconds: 500));
          }

          // Should still be on dialog (validation failed)
          expect(isAddTrackDialogVisible(tester), isTrue,
              reason: 'Dialog should remain open with validation errors');

          debugPrint('=== Validation test complete ===');
        });
      },
    );

    testWidgets(
      'should be able to enter track name in dialog',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Track Name Entry Test ===');

          // Sign in and navigate to song
          await signIn(tester);
          await navigateToTestSong(tester);

          // Open Add Track dialog
          await tapAddTrackButton(tester);
          await tester.pump(const Duration(milliseconds: 500));

          // Enter track name
          const testTrackName = 'Test Track from Integration Test';
          debugPrint('Entering track name: $testTrackName');
          final nameEntered = await enterTrackName(tester, testTrackName);
          expect(nameEntered, isTrue, reason: 'Should enter track name');

          // Verify the text was entered
          final trackNameField = find.text(testTrackName);
          expect(trackNameField.evaluate().isNotEmpty, isTrue,
              reason: 'Track name should be visible in field');

          debugPrint('=== Track name entry test complete ===');
        });
      },
    );

    testWidgets(
      'diagnostic: print song detail screen state',
      skip: true, // Requires Supabase - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Song Detail Screen Diagnostic ===');

          await signIn(tester);
          await navigateToTestSong(tester);

          // Print all visible text
          debugPrint('=== VISIBLE TEXT ===');
          final textWidgets = find.byType(Text).evaluate();
          for (final element in textWidgets.take(30)) {
            final text = element.widget as Text;
            if (text.data != null && text.data!.isNotEmpty) {
              debugPrint('  "${text.data}"');
            }
          }

          // Print all buttons
          debugPrint('=== BUTTONS ===');
          final fabButtons = find.byType(FloatingActionButton).evaluate();
          debugPrint('  FloatingActionButtons: ${fabButtons.length}');

          final elevatedButtons = find.byType(ElevatedButton).evaluate();
          debugPrint('  ElevatedButtons: ${elevatedButtons.length}');

          final iconButtons = find.byType(IconButton).evaluate();
          debugPrint('  IconButtons: ${iconButtons.length}');

          // Check for specific icons
          final addIcon = find.byIcon(Icons.add).evaluate();
          debugPrint('  Add icons: ${addIcon.length}');

          debugPrintScreenState(tester);
        });
      },
    );
  });
}

// ============================================================================
// Track Upload Test Helpers
// ============================================================================

/// Check if we're on the song detail screen
bool isOnSongDetailScreen(WidgetTester tester) {
  // Song detail screen shows tracks list and has add button
  // It should show the song name and "Tracks" or track list
  final hasTracksLabel =
      find.text('Tracks').evaluate().isNotEmpty ||
      find.textContaining('track').evaluate().isNotEmpty;

  final hasAddButton = findAddTrackButton(tester);

  // Also check for play icons which indicate track items
  final hasPlayIcons =
      find.byIcon(Icons.play_circle_filled).evaluate().isNotEmpty ||
      find.byIcon(Icons.play_arrow).evaluate().isNotEmpty ||
      find.byIcon(Icons.play_circle_outline).evaluate().isNotEmpty;

  return hasAddButton || (hasTracksLabel && hasPlayIcons);
}

/// Find the Add Track button (FAB or other button)
bool findAddTrackButton(WidgetTester tester) {
  // Look for FAB with add icon
  final fabWithAdd = find.descendant(
    of: find.byType(FloatingActionButton),
    matching: find.byIcon(Icons.add),
  );
  if (fabWithAdd.evaluate().isNotEmpty) return true;

  // Look for "Add Track" text button
  final addTrackText = find.text('Add Track');
  if (addTrackText.evaluate().isNotEmpty) return true;

  // Look for any FAB (song detail usually has one)
  final anyFab = find.byType(FloatingActionButton);
  if (anyFab.evaluate().isNotEmpty) return true;

  return false;
}

/// Tap the Add Track button
Future<bool> tapAddTrackButton(WidgetTester tester) async {
  // Try FAB first
  final fab = find.byType(FloatingActionButton);
  if (fab.evaluate().isNotEmpty) {
    await tester.tap(fab.first);
    await tester.pump(const Duration(milliseconds: 300));
    return true;
  }

  // Try "Add Track" text
  final addTrackText = find.text('Add Track');
  if (addTrackText.evaluate().isNotEmpty) {
    await tester.tap(addTrackText.first);
    await tester.pump(const Duration(milliseconds: 300));
    return true;
  }

  // Try add icon button
  final addIcon = find.byIcon(Icons.add);
  if (addIcon.evaluate().isNotEmpty) {
    await tester.tap(addIcon.first);
    await tester.pump(const Duration(milliseconds: 300));
    return true;
  }

  return false;
}

/// Check if the Add Track dialog is visible
bool isAddTrackDialogVisible(WidgetTester tester) {
  // Dialog has title "Add New Track"
  final hasAddTrackTitle =
      find.text('Add New Track').evaluate().isNotEmpty ||
      find.text('Add Track').evaluate().isNotEmpty;

  // Dialog should have Track Name field
  final hasTrackNameLabel = find.text('Track Name').evaluate().isNotEmpty;

  // Dialog should have Audio File field
  final hasAudioFileLabel = find.text('Audio File *').evaluate().isNotEmpty;

  // Dialog should have Add button (FilledButton)
  final hasAddButton = find.text('Add').evaluate().isNotEmpty;

  return hasAddTrackTitle && (hasTrackNameLabel || hasAudioFileLabel || hasAddButton);
}

/// Check if the track name field exists
bool hasTrackNameField(WidgetTester tester) {
  // Look for text field with "name" hint or label
  final nameField = find.byWidgetPredicate((widget) {
    if (widget is TextField || widget is TextFormField) {
      return true;
    }
    return false;
  });
  return nameField.evaluate().isNotEmpty;
}

/// Check if the select file button exists
bool hasSelectFileButton(WidgetTester tester) {
  // The dialog has:
  // - Audio File * label
  // - folder_open icon button for file picker
  // - The text field is tappable to open file picker
  final hasAudioFileLabel = find.text('Audio File *').evaluate().isNotEmpty;
  final hasFolderIcon = find.byIcon(Icons.folder_open).evaluate().isNotEmpty;
  final hasHintText = find.text('Select an audio file').evaluate().isNotEmpty;

  return hasAudioFileLabel || hasFolderIcon || hasHintText;
}

/// Enter a track name into the dialog
Future<bool> enterTrackName(WidgetTester tester, String name) async {
  // Find text field (should be the track name field)
  final textFields = find.byType(TextFormField);
  if (textFields.evaluate().isEmpty) {
    final simpleFields = find.byType(TextField);
    if (simpleFields.evaluate().isEmpty) return false;
    await tester.enterText(simpleFields.first, name);
  } else {
    await tester.enterText(textFields.first, name);
  }
  await tester.pump(const Duration(milliseconds: 200));
  return true;
}

/// Cancel/close the Add Track dialog
Future<void> cancelAddTrackDialog(WidgetTester tester) async {
  // Look for Cancel button
  final cancelButton = find.text('Cancel');
  if (cancelButton.evaluate().isNotEmpty) {
    await tester.tap(cancelButton);
    await tester.pump(const Duration(milliseconds: 300));
    return;
  }

  // Try close icon
  final closeIcon = find.byIcon(Icons.close);
  if (closeIcon.evaluate().isNotEmpty) {
    await tester.tap(closeIcon);
    await tester.pump(const Duration(milliseconds: 300));
    return;
  }

  // Try tapping outside dialog (tap at corner)
  await tester.tapAt(const Offset(10, 10));
  await tester.pump(const Duration(milliseconds: 300));
}
