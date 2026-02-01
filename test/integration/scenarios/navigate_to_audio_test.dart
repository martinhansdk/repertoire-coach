/// Navigation to audio player integration test scenario
///
/// Tests navigating from sign-in through to the audio player screen.
///
/// Run with:
/// ```
/// mcp__flutter__flutter_test(path: "test/integration/scenarios/navigate_to_audio_test.dart")
/// ```
///
/// Note: These tests require a real Supabase connection and are skipped by default.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Navigate to Audio Player Scenario', () {
    testWidgets(
      'should navigate from sign-in to audio player',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          debugPrint('=== Starting navigation test ===');

          // Sign in
          debugPrint('Signing in...');
          expect(isOnSignInScreen(tester), isTrue);
          await signIn(tester);
          debugPrintScreenState(tester);

          // Go to choir
          debugPrint('Navigating to choir: ${TestData.testChoirName}');
          final choirOk = await goToChoir(tester, TestData.testChoirName);
          expect(choirOk, isTrue, reason: 'Should navigate to choir');
          debugPrintScreenState(tester);

          // Go to concert
          debugPrint('Navigating to concert: ${TestData.testConcertName}');
          final concertOk = await goToConcert(tester, TestData.testConcertName);
          expect(concertOk, isTrue, reason: 'Should navigate to concert');
          debugPrintScreenState(tester);

          // Go to song (audio player)
          debugPrint('Navigating to song: ${TestData.testSongName}');
          final songOk = await goToSong(tester, TestData.testSongName);
          expect(songOk, isTrue, reason: 'Should navigate to song');
          debugPrintScreenState(tester);

          // Verify audio player screen
          debugPrint('Verifying audio player screen...');
          expect(isOnAudioPlayerScreen(tester), isTrue,
              reason: 'Should be on audio player screen');

          // Verify test track is visible
          final trackVisible =
              find.text(TestData.testTrackWithAudio).evaluate().isNotEmpty;
          expect(trackVisible, isTrue,
              reason: 'Test track should be visible');

          debugPrint('=== Navigation test complete ===');
        });
      },
    );
  });
}
