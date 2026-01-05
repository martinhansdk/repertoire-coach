import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton service for managing Supabase client initialization and access.
///
/// This service provides centralized access to the Supabase client throughout
/// the application. It must be initialized before use by calling [initialize].
///
/// Example:
/// ```dart
/// await SupabaseService.initialize(
///   url: 'https://your-project.supabase.co',
///   anonKey: 'your-anon-key',
/// );
/// final user = SupabaseService.instance.currentUser;
/// ```
class SupabaseService {
  static SupabaseService? _instance;

  /// Get the singleton instance.
  ///
  /// Throws [StateError] if [initialize] has not been called yet.
  static SupabaseService get instance {
    if (_instance == null) {
      throw StateError(
        'SupabaseService has not been initialized. '
        'Call SupabaseService.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if the service has been initialized.
  static bool get isInitialized => _instance != null;

  late final SupabaseClient _client;

  /// Get the Supabase client.
  SupabaseClient get client => _client;

  SupabaseService._();

  /// Initialize the Supabase service.
  ///
  /// This must be called once during app startup, before accessing [instance].
  /// Subsequent calls will throw [StateError].
  ///
  /// Parameters:
  /// - [url]: The Supabase project URL
  /// - [anonKey]: The Supabase anonymous/public API key
  ///
  /// Throws:
  /// - [StateError] if already initialized
  /// - [ArgumentError] if url or anonKey are empty
  static Future<SupabaseService> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_instance != null) {
      throw StateError('SupabaseService has already been initialized.');
    }

    if (url.isEmpty) {
      throw ArgumentError.value(url, 'url', 'Cannot be empty');
    }

    if (anonKey.isEmpty) {
      throw ArgumentError.value(anonKey, 'anonKey', 'Cannot be empty');
    }

    // Initialize Supabase with platform-specific auth options
    if (kIsWeb) {
      // On web, configure PKCE flow and session detection for proper
      // handling of email confirmation and password reset flows
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
      );
    } else {
      // On mobile platforms, use default auth options
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: false,
      );
    }

    final service = SupabaseService._();
    service._client = Supabase.instance.client;
    _instance = service;

    return service;
  }

  /// Reset the singleton instance (for testing purposes only).
  static void reset() {
    _instance = null;
  }

  // Convenience getters

  /// Get the currently authenticated user, or null if not authenticated.
  User? get currentUser => _client.auth.currentUser;

  /// Get the current user's ID, or null if not authenticated.
  String? get currentUserId => currentUser?.id;

  /// Check if a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes.
  ///
  /// Emits an event whenever the user signs in, signs out, or the session changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
