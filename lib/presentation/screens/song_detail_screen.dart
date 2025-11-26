import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../providers/track_provider.dart';
import '../widgets/add_track_dialog.dart';
import '../widgets/track_card.dart';

/// Song Detail Screen
///
/// Displays song information and all tracks for a specific song.
/// Tracks are sorted chronologically (oldest first).
class SongDetailScreen extends ConsumerWidget {
  final String songId;
  final String songTitle;
  final String concertName;

  const SongDetailScreen({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.concertName,
  });

  Future<void> _showAddTrackDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AddTrackDialog(
        songId: songId,
        songTitle: songTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksBySongProvider(songId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              songTitle,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              concertName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return _EmptyState(
              songTitle: songTitle,
              onAddTrack: () => _showAddTrackDialog(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh the tracks list
              ref.invalidate(tracksBySongProvider(songId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.paddingSmall,
              ),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return TrackCard(
                  track: track,
                  onTap: () {
                    // TODO: Navigate to track playback screen or handle tap
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tapped: ${track.name}'),
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
            ref.invalidate(tracksBySongProvider(songId));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTrackDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Track'),
      ),
    );
  }
}

/// Empty state when no tracks are available
class _EmptyState extends StatelessWidget {
  final String songTitle;
  final VoidCallback onAddTrack;

  const _EmptyState({
    required this.songTitle,
    required this.onAddTrack,
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
              Icons.audiotrack_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No Tracks Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Add your first track to this song',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            FilledButton.icon(
              onPressed: onAddTrack,
              icon: const Icon(Icons.add),
              label: const Text('Add Track'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state when track loading fails
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
              'Error Loading Tracks',
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
