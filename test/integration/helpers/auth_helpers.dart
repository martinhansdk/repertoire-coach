/// Authentication test helpers
///
/// Helpers for signing in, signing out, and verifying authentication state
/// in integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_config.dart';
import 'widget_helpers.dart';

/// Sign in with the test account credentials
///
/// Assumes the app is showing the sign-in screen.
/// Returns true if sign-in was successful (navigated away from sign-in screen).
Future<bool> signIn(
  WidgetTester tester, {
  String? email,
  String? password,
}) async {
  final testEmail = email ?? TestCredentials.email;
  final testPassword = password ?? TestCredentials.password;

  // Find email field
  final emailField = find.byWidgetPredicate((widget) {
    if (widget is TextFormField || widget is TextField) {
      return true;
    }
    return false;
  }).first;

  // Find password field (second text field)
  final passwordField = find.byWidgetPredicate((widget) {
    if (widget is TextFormField || widget is TextField) {
      return true;
    }
    return false;
  }).at(1);

  // Enter credentials
  await tester.enterText(emailField, testEmail);
  await tester.pump();

  await tester.enterText(passwordField, testPassword);
  await tester.pump();

  // Find and tap sign in button
  final signInButton = find.widgetWithText(FilledButton, 'Sign In');
  if (signInButton.evaluate().isEmpty) {
    // Try other button types
    final altButton = find.text('Sign In').first;
    await tester.tap(altButton);
  } else {
    await tester.tap(signInButton);
  }

  // Wait for sign-in to complete
  await tester.pump();
  await waitForLoading(tester);

  // Check if we navigated away from sign-in screen
  final stillOnSignIn = find.text('Sign In').evaluate().isNotEmpty &&
      find.text('Forgot Password?').evaluate().isNotEmpty;

  return !stillOnSignIn;
}

/// Sign out from the app
///
/// Looks for a sign-out option in the app bar menu or settings.
Future<void> signOut(WidgetTester tester) async {
  // Look for menu/settings icon
  final menuButton = find.byIcon(Icons.more_vert);
  if (menuButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, menuButton);

    final signOutOption = find.text('Sign Out');
    if (signOutOption.evaluate().isNotEmpty) {
      await tapAndSettle(tester, signOutOption);
      await waitForLoading(tester);
      return;
    }
  }

  // Try account/profile icon
  final accountButton = find.byIcon(Icons.account_circle);
  if (accountButton.evaluate().isNotEmpty) {
    await tapAndSettle(tester, accountButton);

    final signOutOption = find.text('Sign Out');
    if (signOutOption.evaluate().isNotEmpty) {
      await tapAndSettle(tester, signOutOption);
      await waitForLoading(tester);
      return;
    }
  }

  throw TestFailure('Could not find sign out option');
}

/// Check if the app is showing the sign-in screen
bool isOnSignInScreen(WidgetTester tester) {
  return find.text('Sign In').evaluate().isNotEmpty &&
      (find.text('Email').evaluate().isNotEmpty ||
          find.text('Password').evaluate().isNotEmpty);
}

/// Check if the user is authenticated (not on sign-in screen)
bool isAuthenticated(WidgetTester tester) {
  return !isOnSignInScreen(tester);
}

/// Wait for authentication to complete after app start
///
/// The app may auto-sign-in if there's a saved session.
Future<void> waitForAuthState(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await waitForLoading(tester);
}
