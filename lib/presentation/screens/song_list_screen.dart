import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/services/sync_service.dart';
import '../providers/song_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/create_song_dialog.dart';
import '../widgets/song_card.dart';
import 'song_detail_screen.dart';

/// Song List Screen
///
/// Displays all songs for a specific concert.
/// Songs are sorted chronologically (oldest first).
class SongListScreen extends ConsumerStatefulWidget {
  final String concertId;
  final String concertName;
  final String choirId;

  const SongListScreen({
    super.key,
    required this.concertId,
    required this.concertName,
    required this.choirId,
  });

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  @override
  void initState() {
    super.initState();
    final syncStatus = ref.read(syncControllerProvider).status;
    if (syncStatus == SyncStatus.idle || syncStatus == SyncStatus.success) {
      ref.read(syncControllerProvider.notifier).syncFromRemote();
    }
  }

  Future<void> _showCreateSongDialog() async {
    await showDialog(
      context: context,
      builder: (context) => CreateSongDialog(
        concertId: widget.concertId,
        concertName: widget.concertName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsByConcertProvider(widget.concertId));
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.concertName),
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return _EmptyState(
              concertName: widget.concertName,
              onAddSong: () => _showCreateSongDialog(),
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
                  ref.invalidate(songsByConcertProvider(widget.concertId));
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
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongCard(
                    song: song,
                    onTap: () {
                      // Navigate to song detail screen (with tracks)
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SongDetailScreen(
                            songId: song.id,
                            songTitle: song.title,
                            concertName: widget.concertName,
                            choirId: widget.choirId,
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
            ref.invalidate(songsByConcertProvider(widget.concertId));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSongDialog(),
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
