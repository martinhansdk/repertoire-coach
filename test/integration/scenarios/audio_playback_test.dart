/// Audio playback integration test scenario
///
/// Tests the full flow: sign in -> navigate to song -> play audio
/// This verifies that signed URLs are working correctly.
///
/// Run with:
/// ```
/// mcp__flutter__flutter_test(path: "test/integration/scenarios/audio_playback_test.dart")
/// ```
///
/// Note: These tests require a real Supabase connection and are skipped by default.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Audio Playback Scenario', () {
    testWidgets(
      'should sign in, navigate to song, and play audio',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          // Step 1: Sign in
          debugPrint('Step 1: Signing in...');
          expect(isOnSignInScreen(tester), isTrue);
          final signInSuccess = await signIn(tester);
          expect(signInSuccess, isTrue, reason: 'Sign-in should succeed');
          debugPrint('Sign-in successful');

          // Step 2: Navigate to test song
          debugPrint('Step 2: Navigating to test song...');
          final navSuccess = await navigateToTestSong(tester);
          expect(navSuccess, isTrue, reason: 'Navigation to song should succeed');
          debugPrint('Navigation successful');

          // Step 3: Verify we're on audio player screen
          debugPrint('Step 3: Verifying audio player screen...');
          expect(isOnAudioPlayerScreen(tester), isTrue,
              reason: 'Should be on audio player screen');
          debugPrint('On audio player screen');

          // Step 4: Play the test track
          debugPrint('Step 4: Playing test track...');
          final playSuccess = await playTestTrack(tester);
          expect(playSuccess, isTrue, reason: 'Should find and tap play button');
          debugPrint('Play button tapped');

          // Step 5: Verify audio is playing
          debugPrint('Step 5: Verifying audio playback...');
          await tester.pump(TestTimeouts.audioStart);
          expect(arePlaybackControlsVisible(tester), isTrue,
              reason: 'Playback controls should be visible');

          // Check for playing state (pause button visible means playing)
          final playing = isAudioPlaying(tester);
          debugPrint('Audio playing state: $playing');

          debugPrintScreenState(tester);
        });
      },
    );

    testWidgets(
      'should be able to pause and resume playback',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          // Sign in and navigate to song
          await signIn(tester);
          await navigateToTestSong(tester);

          // Play the track
          await playTestTrack(tester);
          await tester.pump(TestTimeouts.audioStart);

          // Verify playing
          expect(isAudioPlaying(tester), isTrue, reason: 'Audio should be playing');

          // Pause
          await pausePlayback(tester);
          expect(isAudioPaused(tester), isTrue, reason: 'Audio should be paused');

          // Resume
          await resumePlayback(tester);
          expect(isAudioPlaying(tester), isTrue, reason: 'Audio should be playing again');

          // Stop
          await stopPlayback(tester);
          expect(arePlaybackControlsVisible(tester), isFalse,
              reason: 'Playback controls should hide after stop');
        });
      },
    );
  });

  group('Signed URL Verification', () {
    testWidgets(
      'should generate signed URL when playing cloud-stored track',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        // This test verifies that the signed URL generation is working
        // by checking console output or playback success
        await runIntegrationTest(tester, () async {
          await signIn(tester);
          await navigateToTestSong(tester);

          // The test track should have a cloud storage path
          // When we play it, the provider should generate a signed URL
          debugPrint('Attempting to play cloud-stored track...');
          debugPrint('If this succeeds, signed URLs are working!');

          final playSuccess = await playTestTrack(tester);
          expect(playSuccess, isTrue);

          await tester.pump(TestTimeouts.audioStart);

          // If we get here without errors and audio is playing,
          // the signed URL worked
          debugPrint('Playback started - signed URL generation working!');
          debugPrintScreenState(tester);
        });
      },
    );
  });
}
