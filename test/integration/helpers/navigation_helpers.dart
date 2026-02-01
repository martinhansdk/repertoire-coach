/// Navigation test helpers
///
/// Helpers for navigating to different screens in integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_config.dart';
import 'widget_helpers.dart';

/// Navigate to a specific choir by name
///
/// Assumes the app is showing the choir list (home screen after sign-in).
Future<bool> goToChoir(WidgetTester tester, String choirName) async {
  // Wait for choir list to load
  await waitForLoading(tester);

  // Find and tap the choir
  final choirTile = findListTileByTitle(choirName);
  if (choirTile.evaluate().isEmpty) {
    // Try scrolling to find it
    final found = await scrollUntilVisible(tester, choirTile);
    if (!found) {
      debugPrint('Could not find choir: $choirName');
      debugPrintAllText(tester);
      return false;
    }
  }

  await tapAndSettle(tester, choirTile);
  await waitForLoading(tester);

  return true;
}

/// Navigate to a specific concert by name
///
/// Assumes the app is showing a choir's detail screen with concerts.
Future<bool> goToConcert(WidgetTester tester, String concertName) async {
  await waitForLoading(tester);

  final concertTile = findListTileByTitle(concertName);
  if (concertTile.evaluate().isEmpty) {
    // Try finding by text alone
    final concertText = find.text(concertName);
    if (concertText.evaluate().isEmpty) {
      final found = await scrollUntilVisible(tester, concertText);
      if (!found) {
        debugPrint('Could not find concert: $concertName');
        debugPrintAllText(tester);
        return false;
      }
    }
    await tapAndSettle(tester, concertText.first);
  } else {
    await tapAndSettle(tester, concertTile);
  }

  await waitForLoading(tester);
  return true;
}

/// Navigate to a specific song by name
///
/// Assumes the app is showing a concert's detail screen with songs.
Future<bool> goToSong(WidgetTester tester, String songName) async {
  await waitForLoading(tester);

  final songTile = findListTileByTitle(songName);
  if (songTile.evaluate().isEmpty) {
    final songText = find.text(songName);
    if (songText.evaluate().isEmpty) {
      final found = await scrollUntilVisible(tester, songText);
      if (!found) {
        debugPrint('Could not find song: $songName');
        debugPrintAllText(tester);
        return false;
      }
    }
    await tapAndSettle(tester, songText.first);
  } else {
    await tapAndSettle(tester, songTile);
  }

  await waitForLoading(tester);
  return true;
}

/// Navigate from home to a song using test data defaults
///
/// Convenience method that navigates: Choir -> Concert -> Song
Future<bool> navigateToTestSong(WidgetTester tester) async {
  final choirOk = await goToChoir(tester, TestData.testChoirName);
  if (!choirOk) return false;

  final concertOk = await goToConcert(tester, TestData.testConcertName);
  if (!concertOk) return false;

  final songOk = await goToSong(tester, TestData.testSongName);
  if (!songOk) return false;

  return true;
}

/// Navigate back using the back button
Future<void> goBack(WidgetTester tester) async {
  final backButton = find.byIcon(Icons.arrow_back);
  if (backButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, backButton.first);
    return;
  }

  // Try the back arrow icon button
  final backArrow = find.byType(BackButton);
  if (backArrow.evaluate().isNotEmpty) {
    await tapAndSettle(tester, backArrow.first);
    return;
  }

  // Use navigator pop as fallback
  final context = tester.element(find.byType(Scaffold).first);
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

/// Check if we're on the home/choir list screen
bool isOnHomeScreen(WidgetTester tester) {
  return find.text('My Choirs').evaluate().isNotEmpty;
}

/// Check if we're on a choir detail screen
bool isOnChoirScreen(WidgetTester tester, String choirName) {
  return find.text(choirName).evaluate().isNotEmpty &&
      find.text('Concerts').evaluate().isNotEmpty;
}

/// Check if we're on a concert detail screen
bool isOnConcertScreen(WidgetTester tester, String concertName) {
  return find.text(concertName).evaluate().isNotEmpty &&
      find.text('Songs').evaluate().isNotEmpty;
}

/// Check if we're on the audio player screen
bool isOnAudioPlayerScreen(WidgetTester tester) {
  // Look for audio player controls
  return find.byIcon(Icons.play_circle_filled).evaluate().isNotEmpty ||
      find.byIcon(Icons.pause_circle_filled).evaluate().isNotEmpty ||
      find.byIcon(Icons.play_arrow).evaluate().isNotEmpty;
}
