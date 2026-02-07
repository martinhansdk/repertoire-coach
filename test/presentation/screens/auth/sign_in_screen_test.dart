import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/repositories/auth_repository.dart';
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
import 'package:repertoire_coach/presentation/screens/auth/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.signInError});

  final Object signInError;

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    throw signInError;
  }

  @override
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError();
  }

  @override
  User? getCurrentUser() => null;

  @override
  Stream<AuthState> watchAuthState() => const Stream<AuthState>.empty();

  @override
  Future<void> resetPassword(String email) async {
    throw UnimplementedError();
  }

  @override
  bool get isAuthenticated => false;
}

void main() {
  testWidgets(
      'shows email confirmation guidance when sign-in fails with unconfirmed email',
      (tester) async {
    final fakeRepository = FakeAuthRepository(
      signInError: const AuthException(
        'Email not confirmed',
        statusCode: '400',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authActionsProvider.overrideWithValue(AuthActions(fakeRepository)),
        ],
        child: const MaterialApp(home: SignInScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'password123',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Please confirm your email address. Check for an email from "Supabase Auth", then sign in.',
      ),
      findsOneWidget,
    );
  });
}
