import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html show window;

/// Implementation of [AuthRepository] using Supabase Auth.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseService _supabaseService;

  AuthRepositoryImpl(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Get the redirect URL for auth callbacks on web.
  ///
  /// On web, this returns the current origin (e.g., http://localhost:8080).
  /// On other platforms, returns null (not needed for mobile).
  String? get _redirectUrl {
    if (kIsWeb) {
      return html.window.location.origin;
    }
    return null;
  }

  @override
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
        emailRedirectTo: _redirectUrl,
      );

      // If sign up successful, create user record in our users table
      if (response.user != null) {
        await _createUserRecord(
          userId: response.user!.id,
          email: email,
          displayName: displayName,
        );
      }

      return response.user;
    } on AuthException catch (e) {
      // Re-throw auth exceptions (invalid email, weak password, etc.)
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      // Wrap other exceptions
      throw Exception('Sign up failed: $e');
    }
  }

  @override
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response.user;
    } on AuthException catch (e) {
      // Re-throw auth exceptions (invalid credentials, etc.)
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      // Wrap other exceptions
      throw Exception('Sign in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  @override
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  @override
  Stream<AuthState> watchAuthState() {
    return _client.auth.onAuthStateChange;
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  @override
  bool get isAuthenticated => getCurrentUser() != null;

  /// Create a user record in the users table after successful sign up.
  ///
  /// This is necessary because Supabase Auth manages the auth.users table,
  /// but we need our own users table for additional user data.
  Future<void> _createUserRecord({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    try {
      await _client.from('users').insert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'language_preference': 'en', // Default language
      });
    } catch (e) {
      // Log error but don't fail sign up if user record creation fails
      // The user is still authenticated via Supabase Auth
      developer.log('Warning: Failed to create user record: $e', name: 'AuthRepositoryImpl', error: e);
    }
  }
}
