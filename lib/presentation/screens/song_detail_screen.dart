import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/services/sync_service.dart';
import '../providers/sync_provider.dart';
import '../providers/track_provider.dart';
import '../widgets/add_track_dialog.dart';
import '../widgets/track_card.dart';
import 'audio_player_screen.dart';

/// Song Detail Screen
///
/// Displays song information and all tracks for a specific song.
/// Tracks are sorted chronologically (oldest first).
class SongDetailScreen extends ConsumerStatefulWidget {
  final String songId;
  final String songTitle;
  final String concertName;
  final String choirId;

  const SongDetailScreen({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.concertName,
    required this.choirId,
  });

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  @override
  void initState() {
    super.initState();
    final syncStatus = ref.read(syncControllerProvider).status;
    if (syncStatus == SyncStatus.idle || syncStatus == SyncStatus.success) {
      ref.read(syncControllerProvider.notifier).syncFromRemote();
    }
  }

  Future<void> _showAddTrackDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddTrackDialog(
        songId: widget.songId,
        songTitle: widget.songTitle,
        choirId: widget.choirId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksBySongProvider(widget.songId));
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.songTitle,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.concertName,
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
              songTitle: widget.songTitle,
              onAddTrack: () => _showAddTrackDialog(),
            );
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
                  ref.invalidate(tracksBySongProvider(widget.songId));
                }
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  0,
                  AppConstants.paddingSmall,
                  0,
                  AppConstants.paddingSmall + bottomInset + 80,
                ),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return TrackCard(
                    track: track,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AudioPlayerScreen(
                            track: track,
                            songTitle: widget.songTitle,
                            concertName: widget.concertName,
                          ),
                        ),
                      );
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
            ref.invalidate(tracksBySongProvider(widget.songId));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTrackDialog(),
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
