import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/core/services/r2_signer_client.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/data/repositories/auth_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight user profile used for displaying choir members.
class MemberProfile {
  final String userId;
  final String email;
  final String? displayName;

  const MemberProfile({
    required this.userId,
    required this.email,
    this.displayName,
  });

  /// Preferred display label: displayName if available, otherwise email.
  String get displayLabel => displayName ?? email;
}

/// Provider for the R2SignerClient.
final r2SignerClientProvider = Provider<R2SignerClient>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return R2SignerClient(supabaseService);
});

/// Provider for the SupabaseService singleton.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  if (!SupabaseService.isInitialized) {
    throw StateError(
      'SupabaseService not initialized. '
      'Initialize it in main.dart before running the app.',
    );
  }
  return SupabaseService.instance;
});

/// Provider for the AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

/// Provider for the current authenticated user.
///
/// Returns the User object if authenticated, null otherwise.
final currentUserProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return authRepository.watchAuthState().map((authState) {
    return authState.session?.user;
  });
});

/// Provider for authentication state (boolean: is authenticated?).
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authAsync = ref.watch(currentUserProvider);

  return authAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Authentication actions provider.
///
/// Provides methods to perform authentication operations.
/// UI screens should handle loading/error states locally.
///
/// Note: After successful sign-in, the UI should trigger a sync from remote
/// using the syncControllerProvider from sync_provider.dart to pull the
/// user's data into the local database.
final authActionsProvider = Provider<AuthActions>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthActions(authRepository);
});

/// Authentication actions class.
class AuthActions {
  final AuthRepository _authRepository;

  AuthActions(this._authRepository);

  /// Sign up a new user.
  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await _authRepository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  /// Sign in an existing user.
  ///
  /// Note: After successful sign-in, the UI should trigger a sync from remote
  /// using syncControllerProvider.notifier.syncFromRemote() to pull the
  /// user's data into the local database.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    return await _authRepository.signIn(
      email: email,
      password: password,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _authRepository.signOut();
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    await _authRepository.resetPassword(email);
  }
}

/// Provider for user lookup operations (find by email, fetch profiles).
final userLookupProvider = Provider<UserLookup>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return UserLookup(supabaseService.client);
});

/// Performs user-discovery queries against the public users table.
class UserLookup {
  final SupabaseClient _client;

  UserLookup(this._client);

  /// Returns the user ID for the given email, or null if no account exists.
  Future<String?> findUserIdByEmail(String email) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return response?['id'] as String?;
    } on PostgrestException catch (e) {
      throw Exception('User lookup failed: ${e.message}');
    }
  }

  /// Fetches profiles for the given user IDs.
  /// Returns only the rows that exist; missing IDs are silently omitted.
  Future<List<MemberProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final response = await _client
          .from('users')
          .select('id, email, display_name')
          .inFilter('id', userIds) as List;
      return response
          .map((json) => MemberProfile(
                userId: json['id'] as String,
                email: json['email'] as String,
                displayName: json['display_name'] as String?,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch user profiles: ${e.message}');
    }
  }
}
