import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/entities/favorite_track.dart';

/// Card widget for displaying a favorite track
///
/// Shows song title (most prominent), track name, and choir name.
/// Provides tap to play and remove from favorites actions.
class FavoriteTrackCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Song title (most prominent)
                    Text(
                      favorite.songTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Track name (secondary)
                    Text(
                      favorite.trackName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Choir name (tertiary, smaller)
                    Text(
                      favorite.choirName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
}
