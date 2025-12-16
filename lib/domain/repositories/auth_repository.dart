import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository interface for authentication operations.
///
/// Provides methods for user authentication including sign up, sign in,
/// sign out, and session management.
abstract class AuthRepository {
  /// Sign up a new user with email and password.
  ///
  /// Returns the created [User] on success, or null if sign up failed.
  ///
  /// Throws:
  /// - [AuthException] if sign up fails (e.g., email already exists)
  /// - [Exception] for other errors
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in an existing user with email and password.
  ///
  /// Returns the authenticated [User] on success, or null if sign in failed.
  ///
  /// Throws:
  /// - [AuthException] if credentials are invalid
  /// - [Exception] for other errors
  Future<User?> signIn({
    required String email,
    required String password,
  });

  /// Sign out the currently authenticated user.
  ///
  /// Throws:
  /// - [Exception] if sign out fails
  Future<void> signOut();

  /// Get the currently authenticated user, or null if not authenticated.
  User? getCurrentUser();

  /// Stream of authentication state changes.
  ///
  /// Emits an event whenever the user signs in, signs out, or the session changes.
  Stream<AuthState> watchAuthState();

  /// Send a password reset email to the specified email address.
  ///
  /// Throws:
  /// - [AuthException] if the operation fails
  /// - [Exception] for other errors
  Future<void> resetPassword(String email);

  /// Check if a user is currently authenticated.
  bool get isAuthenticated;
}
