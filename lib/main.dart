import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'presentation/screens/concert_list_screen.dart';

void main() {
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
/// and routing to the concert list screen.
class RepertoireCoachApp extends StatelessWidget {
  const RepertoireCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const ConcertListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
