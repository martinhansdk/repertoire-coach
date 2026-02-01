/// Sign-in integration test scenario
///
/// Tests the sign-in flow and verifies the user reaches the home screen.
///
/// Run with:
/// ```
/// mcp__flutter__flutter_test(path: "test/integration/scenarios/sign_in_test.dart")
/// ```
///
/// Note: These tests require a real Supabase connection and are skipped by default.
/// To run them, remove the skip parameter or set environment variables.
library;

import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('Sign In Scenario', () {
    testWidgets(
      'should sign in with valid credentials and reach home screen',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          // Verify we start on sign-in screen
          expect(isOnSignInScreen(tester), isTrue,
              reason: 'Should start on sign-in screen');

          // Sign in
          final signInSuccess = await signIn(tester);
          expect(signInSuccess, isTrue, reason: 'Sign-in should succeed');

          // Verify we're on the home screen (choir list)
          expect(isOnHomeScreen(tester), isTrue,
              reason: 'Should be on home screen after sign-in');

          // Verify we can see the user's choirs
          final hasChoirs = find.text(TestData.testChoirName).evaluate().isNotEmpty;
          expect(hasChoirs, isTrue,
              reason: 'Should see test choir after sign-in');

          debugPrintScreenState(tester);
        });
      },
    );

    testWidgets(
      'should show error for invalid credentials',
      skip: true, // Requires Supabase connection - run manually
      (tester) async {
        await runIntegrationTest(tester, () async {
          expect(isOnSignInScreen(tester), isTrue);

          // Try to sign in with wrong password
          final signInResult = await signIn(
            tester,
            email: TestCredentials.email,
            password: 'wrong-password',
          );

          // Should still be on sign-in screen
          expect(signInResult, isFalse,
              reason: 'Sign-in should fail with wrong password');
          expect(isOnSignInScreen(tester), isTrue,
              reason: 'Should stay on sign-in screen after failed sign-in');
        });
      },
    );
  });
}
