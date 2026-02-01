/// Audio playback test helpers
///
/// Helpers for controlling audio playback and verifying audio state
/// in integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_config.dart';
import 'widget_helpers.dart';

/// Play a track by name
///
/// Assumes the app is showing the audio player screen with track list.
/// Returns true if the play button was found and tapped.
Future<bool> playTrack(WidgetTester tester, String trackName) async {
  await waitForLoading(tester);

  // Find the track in the list
  final trackTile = findListTileByTitle(trackName);
  if (trackTile.evaluate().isEmpty) {
    debugPrint('Could not find track: $trackName');
    debugPrintAllText(tester);
    return false;
  }

  // Find the play button within the track tile's row
  // The play button should be an IconButton with play_arrow icon
  final playButtons = find.byIcon(Icons.play_arrow);
  if (playButtons.evaluate().isEmpty) {
    debugPrint('No play buttons found on screen');
    return false;
  }

  // Tap the first play button (or the one associated with our track)
  await tapAndSettle(tester, playButtons.first);

  // Wait for audio to start
  await tester.pump(TestTimeouts.audioStart);

  return true;
}

/// Play the test track (using default test data)
Future<bool> playTestTrack(WidgetTester tester) async {
  return playTrack(tester, TestData.testTrackWithAudio);
}

/// Pause the currently playing track
Future<void> pausePlayback(WidgetTester tester) async {
  final pauseButton = find.byIcon(Icons.pause_circle_filled);
  if (pauseButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, pauseButton);
    return;
  }

  final pauseSmall = find.byIcon(Icons.pause);
  if (pauseSmall.evaluate().isNotEmpty) {
    await tapAndSettle(tester, pauseSmall.first);
    return;
  }

  debugPrint('No pause button found');
}

/// Resume paused playback
Future<void> resumePlayback(WidgetTester tester) async {
  final playButton = find.byIcon(Icons.play_circle_filled);
  if (playButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, playButton);
    return;
  }

  final playSmall = find.byIcon(Icons.play_arrow);
  if (playSmall.evaluate().isNotEmpty) {
    await tapAndSettle(tester, playSmall.first);
  }
}

/// Stop playback completely
Future<void> stopPlayback(WidgetTester tester) async {
  final stopButton = find.byIcon(Icons.stop);
  if (stopButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, stopButton.first);
    return;
  }

  // Try finding a stop text button
  final stopTextButton = find.text('Stop');
  if (stopTextButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, stopTextButton.first);
  }
}

/// Check if audio appears to be playing
///
/// Looks for visual indicators that audio is playing:
/// - Pause button visible (instead of play)
/// - Progress indicator moving
/// - Playing state indicator
bool isAudioPlaying(WidgetTester tester) {
  // If we see a pause button, audio is likely playing
  final pauseButton = find.byIcon(Icons.pause_circle_filled);
  if (pauseButton.evaluate().isNotEmpty) {
    return true;
  }

  // Check for pause icon in smaller buttons
  final pauseSmall = find.byIcon(Icons.pause);
  if (pauseSmall.evaluate().isNotEmpty) {
    return true;
  }

  return false;
}

/// Check if audio appears to be paused
bool isAudioPaused(WidgetTester tester) {
  // If we see a play button (not in track list), audio is paused
  final playButton = find.byIcon(Icons.play_circle_filled);
  return playButton.evaluate().isNotEmpty;
}

/// Check if the playback controls are visible
bool arePlaybackControlsVisible(WidgetTester tester) {
  // Look for common playback controls
  final hasPlayPause = find.byIcon(Icons.play_circle_filled).evaluate().isNotEmpty ||
      find.byIcon(Icons.pause_circle_filled).evaluate().isNotEmpty;

  final hasSeekControls = find.byIcon(Icons.replay_10).evaluate().isNotEmpty ||
      find.byIcon(Icons.skip_previous).evaluate().isNotEmpty;

  return hasPlayPause || hasSeekControls;
}

/// Get the current playback position text (if visible)
String? getPlaybackPositionText(WidgetTester tester) {
  // Look for text matching time format (MM:SS)
  final timePattern = RegExp(r'^\d{1,2}:\d{2}$');

  final allText = find.byType(Text).evaluate();
  for (final element in allText) {
    final text = element.widget as Text;
    if (text.data != null && timePattern.hasMatch(text.data!)) {
      return text.data;
    }
  }

  return null;
}

/// Seek forward using the +10s button
Future<void> seekForward(WidgetTester tester) async {
  final forwardButton = find.byIcon(Icons.forward_10);
  if (forwardButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, forwardButton);
  }
}

/// Seek backward using the -10s button
Future<void> seekBackward(WidgetTester tester) async {
  final backwardButton = find.byIcon(Icons.replay_10);
  if (backwardButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, backwardButton);
  }
}

/// Skip to next track
Future<void> nextTrack(WidgetTester tester) async {
  final nextButton = find.byIcon(Icons.skip_next);
  if (nextButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, nextButton);
    await tester.pump(TestTimeouts.audioStart);
  }
}

/// Skip to previous track
Future<void> previousTrack(WidgetTester tester) async {
  final prevButton = find.byIcon(Icons.skip_previous);
  if (prevButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, prevButton);
    await tester.pump(TestTimeouts.audioStart);
  }
}
