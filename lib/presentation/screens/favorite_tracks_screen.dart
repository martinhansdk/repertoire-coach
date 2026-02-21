import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../providers/favorite_track_provider.dart';
import '../providers/song_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/favorite_track_card.dart';
import 'audio_player_screen.dart';

/// Favorite Tracks Screen
///
/// Displays all user's favorite tracks with denormalized data
/// (song title, track name, choir name) for quick access.
/// Users can play tracks directly or remove from favorites.
class FavoriteTracksScreen extends ConsumerWidget {
  const FavoriteTracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      body: favoritesAsync.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return const _EmptyState();
          }

          return SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(syncControllerProvider.notifier).syncFromRemote();
                } catch (_) {
                  // Keep pull-to-refresh functional in offline/test environments.
                } finally {
                  ref.invalidate(favoritesProvider);
                }
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  0,
                  AppConstants.paddingSmall,
                  0,
                  AppConstants.paddingSmall + bottomInset,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  return FavoriteTrackCard(
                    favorite: favorite,
                    onTap: () async {
                      // Look up song to get title
                      final song = await ref.read(
                        songByIdProvider(favorite.track.songId).future,
                      );
                      final songTitle = song?.title ?? 'Unknown Song';

                      // Navigate to audio player with the Track from favorite
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              track: favorite.track,
                              songTitle: songTitle,
                              concertName: '', // Not shown in audio player
                            ),
                          ),
                        );
                      }
                    },
                    onRemove: () async {
                      // Remove from favorites
                      await ref
                          .read(favoriteTrackActionsProvider)
                          .removeFavorite(favorite.track.id);

                      // Show snackbar confirmation
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Removed "${favorite.track.name}" from favorites',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => _ErrorState(
          error: error.toString(),
          onRetry: () {
            ref.invalidate(favoritesProvider);
          },
        ),
      ),
    );
  }
}

/// Empty state when no favorites exist
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No Favorite Tracks',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Tap the heart icon on any track to add it to your favorites',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state when favorite loading fails
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Error Loading Favorites',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
