import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/environment.dart';
import 'core/constants.dart';
import 'core/services/supabase_service.dart';
import 'core/theme.dart';
import 'presentation/screens/auth/auth_wrapper.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if credentials are configured
  if (Environment.isSupabaseConfigured) {
    try {
      await SupabaseService.initialize(
        url: Environment.supabaseUrl,
        anonKey: Environment.supabaseAnonKey,
      );
      developer.log('Supabase initialized successfully', name: 'main');
    } catch (e) {
      developer.log('Failed to initialize Supabase: $e', name: 'main', error: e);
      developer.log('App will run in offline-only mode', name: 'main');
    }
  } else {
    developer.log('Supabase credentials not configured - running in offline-only mode', name: 'main');
  }

  runApp(
    // Wrap the app in ProviderScope to enable Riverpod
    const ProviderScope(
      child: RepertoireCoachApp(),
    ),
  );
}

/// Repertoire Coach Application
///
/// The root widget of the application, configured with theme
/// and bottom navigation between choirs and concerts.
class RepertoireCoachApp extends StatelessWidget {
  const RepertoireCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: SupabaseService.isInitialized
          ? const AuthWrapper() // Cloud-enabled mode
          : const HomeScreen(), // Offline-only mode
      debugShowCheckedModeBanner: false,
    );
  }
}
