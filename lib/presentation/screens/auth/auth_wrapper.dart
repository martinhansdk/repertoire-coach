import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
import 'package:repertoire_coach/presentation/screens/auth/sign_in_screen.dart';
import 'package:repertoire_coach/presentation/screens/home_screen.dart';

/// Wrapper widget that routes to either the sign in screen or the main app
/// based on the user's authentication state.
///
/// This widget should be used as the root widget of the app after
/// MaterialApp initialization.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          // Not authenticated - show sign in screen
          return const SignInScreen();
        } else {
          // Authenticated - show main app with bottom navigation
          return const HomeScreen();
        }
      },
      loading: () {
        // Loading authentication state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        // Error checking authentication state
        // Show sign in screen but display error message
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Authentication Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Retry by showing sign in screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SignInScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to Sign In'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
