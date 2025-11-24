import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'presentation/screens/choir_list_screen.dart';
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
      home: const _HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Home screen with bottom navigation
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    ChoirListScreen(),
    ConcertListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Choirs',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Concerts',
          ),
        ],
      ),
    );
  }
}
