import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
import 'package:repertoire_coach/presentation/screens/auth/reset_password_screen.dart';
import 'package:repertoire_coach/presentation/screens/auth/sign_in_screen.dart';
import 'package:repertoire_coach/presentation/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper widget that routes to either the sign in screen or the main app
/// based on the user's authentication state.
///
/// This widget should be used as the root widget of the app after
/// MaterialApp initialization.
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _showResetPassword = false;

  @override
  void initState() {
    super.initState();
    _checkForPasswordRecovery();
  }

  void _checkForPasswordRecovery() {
    // Listen to auth state changes to detect password recovery
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _showResetPassword = true;
        });
      } else if (event == AuthChangeEvent.signedIn && _showResetPassword) {
        // After successful password reset, clear the flag
        setState(() {
          _showResetPassword = false;
        });
      }
    });
    // Note: Subscription will be automatically cleaned up when widget is disposed
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        // Check if we should show password reset screen
        if (_showResetPassword && user != null) {
          return const ResetPasswordScreen();
        }

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
