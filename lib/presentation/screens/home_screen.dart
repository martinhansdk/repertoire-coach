import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/presentation/screens/choir_list_screen.dart';
import 'package:repertoire_coach/presentation/screens/favorite_tracks_screen.dart';
import '../providers/favorite_track_provider.dart';

/// Home screen with bottom navigation between Choirs and Favorites.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasInitialized = false;

  static const List<Widget> _screens = [
    ChoirListScreen(),
    FavoriteTracksScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final favoriteCountAsync = ref.watch(favoriteCountProvider);

    return favoriteCountAsync.when(
      data: (count) {
        // Only update selectedIndex on first load
        if (!_hasInitialized) {
          _selectedIndex = count > 0 ? 1 : 0; // Favorites if any, else Choirs
          _hasInitialized = true;
        }

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
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => Scaffold(
        body: _screens[0], // Default to Choirs on error
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
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
          ],
        ),
      ),
    );
  }
}
