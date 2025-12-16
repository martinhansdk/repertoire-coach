import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/data/repositories/auth_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// State notifier for authentication actions.
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AsyncValue.data(null));

  /// Sign up a new user.
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  /// Sign in an existing user.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signIn(
        email: email,
        password: password,
      );
    });
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.signOut();
    });
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authRepository.resetPassword(email);
    });
  }
}

/// Provider for the AuthNotifier.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
