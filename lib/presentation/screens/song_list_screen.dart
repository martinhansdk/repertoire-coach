import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../providers/song_provider.dart';
import '../widgets/create_song_dialog.dart';
import '../widgets/song_card.dart';

/// Song List Screen
///
/// Displays all songs for a specific concert.
/// Songs are sorted chronologically (oldest first).
class SongListScreen extends ConsumerWidget {
  final String concertId;
  final String concertName;

  const SongListScreen({
    super.key,
    required this.concertId,
    required this.concertName,
  });

  Future<void> _showCreateSongDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => CreateSongDialog(
        concertId: concertId,
        concertName: concertName,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByConcertProvider(concertId));

    return Scaffold(
      appBar: AppBar(
        title: Text(concertName),
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return _EmptyState(
              concertName: concertName,
              onAddSong: () => _showCreateSongDialog(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh the songs list
              ref.invalidate(songsByConcertProvider(concertId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.paddingSmall,
              ),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongCard(
                  song: song,
                  onTap: () {
                    // TODO: Navigate to song detail screen (with tracks)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tapped: ${song.title}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => _ErrorState(
          error: error.toString(),
          onRetry: () {
            ref.invalidate(songsByConcertProvider(concertId));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSongDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
      ),
    );
  }
}

/// Empty state when no songs are available
class _EmptyState extends StatelessWidget {
  final String concertName;
  final VoidCallback onAddSong;

  const _EmptyState({
    required this.concertName,
    required this.onAddSong,
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
              Icons.music_note_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No Songs Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Add your first song to this concert',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            FilledButton.icon(
              onPressed: onAddSong,
              icon: const Icon(Icons.add),
              label: const Text('Add Song'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state when song loading fails
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
              'Error Loading Songs',
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
