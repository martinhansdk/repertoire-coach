import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../domain/entities/favorite_track.dart';
import '../providers/song_provider.dart';
import '../providers/concert_provider.dart';
import '../providers/choir_provider.dart';

/// Card widget for displaying a favorite track
///
/// Shows song title (most prominent), track name, and choir name.
/// Looks up related data via providers to ensure data consistency.
/// Provides tap to play and remove from favorites actions.
class FavoriteTrackCard extends ConsumerWidget {
  final FavoriteTrack favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FavoriteTrackCard({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Look up song to get title and concert ID
    final songAsync = ref.watch(songByIdProvider(favorite.track.songId));

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            children: [
              // Audio icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.audiotrack,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMedium),

              // Track info
              Expanded(
                child: songAsync.when(
                  data: (song) {
                    if (song == null) {
                      return Text('Song not found', style: theme.textTheme.bodyMedium);
                    }

                    // Look up concert to get choir ID
                    final concertAsync = ref.watch(concertByIdProvider(song.concertId));

                    return concertAsync.when(
                      data: (concert) {
                        if (concert == null) {
                          return _buildTrackInfo(theme, song.title, favorite.track.name, 'Unknown Choir');
                        }

                        // Look up choir to get name
                        final choirAsync = ref.watch(choirByIdProvider(concert.choirId));

                        return choirAsync.when(
                          data: (choir) => _buildTrackInfo(
                            theme,
                            song.title,
                            favorite.track.name,
                            choir?.name ?? 'Unknown Choir',
                          ),
                          loading: () => _buildTrackInfo(theme, song.title, favorite.track.name, '...'),
                          error: (_, __) => _buildTrackInfo(theme, song.title, favorite.track.name, 'Error'),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => Text('Error loading concert', style: theme.textTheme.bodyMedium),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => Text('Error loading song', style: theme.textTheme.bodyMedium),
                ),
              ),

              // Remove from favorites button
              IconButton(
                icon: const Icon(Icons.favorite),
                color: theme.colorScheme.error,
                tooltip: 'Remove from favorites',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(ThemeData theme, String songTitle, String trackName, String choirName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Song title (most prominent)
        Text(
          songTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),

        // Track name (secondary)
        Text(
          trackName,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),

        // Choir name (tertiary, smaller)
        Text(
          choirName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
