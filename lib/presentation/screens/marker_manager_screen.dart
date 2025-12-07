import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../providers/marker_provider.dart';
import '../widgets/marker_dialog.dart';
import '../widgets/marker_set_dialog.dart';

/// Hardcoded user ID for local-first mode
const String _currentUserId = 'local-user-1';

/// Marker Manager Screen
///
/// Manages marker sets and markers for a specific track.
/// Users can create, edit, and delete marker sets and markers.
class MarkerManagerScreen extends ConsumerWidget {
  final String trackId;
  final String trackName;

  const MarkerManagerScreen({
    super.key,
    required this.trackId,
    required this.trackName,
  });

  Future<void> _showCreateMarkerSetDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => MarkerSetDialog(trackId: trackId),
    );
  }

  Future<void> _deleteMarkerSet(
    BuildContext context,
    WidgetRef ref,
    String markerSetId,
    String markerSetName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Marker Set'),
        content: Text(
          'Are you sure you want to delete "$markerSetName" and all its markers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(markerRepositoryProvider);
        await repository.deleteMarkerSet(markerSetId);

        if (context.mounted) {
          ref.invalidate(markerSetsByTrackProvider((trackId, _currentUserId)));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marker set deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting marker set: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markerSetsAsync = ref.watch(markerSetsByTrackProvider((trackId, _currentUserId)));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Markers',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              trackName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: markerSetsAsync.when(
        data: (markerSets) {
          if (markerSets.isEmpty) {
            return _EmptyState(
              onCreateMarkerSet: () => _showCreateMarkerSetDialog(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(markerSetsByTrackProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.paddingSmall,
              ),
              itemCount: markerSets.length,
              itemBuilder: (context, index) {
                final markerSet = markerSets[index];
                return _MarkerSetCard(
                  trackId: trackId,
                  markerSet: markerSet,
                  onDelete: () => _deleteMarkerSet(
                    context,
                    ref,
                    markerSet.id,
                    markerSet.name,
                  ),
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
            ref.invalidate(markerSetsByTrackProvider);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMarkerSetDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Set'),
      ),
    );
  }
}

/// Card displaying a marker set and its markers
class _MarkerSetCard extends ConsumerWidget {
  final String trackId;
  final dynamic markerSet; // MarkerSet type
  final VoidCallback onDelete;

  const _MarkerSetCard({
    required this.trackId,
    required this.markerSet,
    required this.onDelete,
  });

  Future<void> _showEditMarkerSetDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => MarkerSetDialog(
        trackId: trackId,
        markerSet: markerSet,
      ),
    );
  }

  Future<void> _showCreateMarkerDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => MarkerDialog(
        markerSetId: markerSet.id,
      ),
    );
  }

  Future<void> _deleteMarker(
    BuildContext context,
    WidgetRef ref,
    String markerId,
    String markerLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Marker'),
        content: Text('Are you sure you want to delete "$markerLabel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(markerRepositoryProvider);
        await repository.deleteMarker(markerId);

        if (context.mounted) {
          ref.invalidate(markersByMarkerSetProvider(markerSet.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marker deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting marker: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final markersAsync = ref.watch(markersByMarkerSetProvider(markerSet.id));

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              markerSet.isShared ? Icons.people : Icons.lock,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(markerSet.name),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditMarkerSetDialog(context);
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
        children: [
          markersAsync.when(
            data: (markers) {
              if (markers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: Column(
                    children: [
                      Text(
                        'No markers yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showCreateMarkerDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Marker'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  ...markers.map((marker) {
                    final position = Duration(milliseconds: marker.positionMs);
                    final minutes = position.inMinutes;
                    final seconds = position.inSeconds % 60;
                    final milliseconds = position.inMilliseconds % 1000;

                    return ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(marker.label),
                      subtitle: Text(
                        '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}',
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            showDialog(
                              context: context,
                              builder: (context) => MarkerDialog(
                                markerSetId: markerSet.id,
                                marker: marker,
                              ),
                            );
                          } else if (value == 'delete') {
                            _deleteMarker(context, ref, marker.id, marker.label);
                          }
                        },
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    child: OutlinedButton.icon(
                      onPressed: () => _showCreateMarkerDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Marker'),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppConstants.paddingMedium),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Text(
                'Error loading markers: $error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no marker sets exist
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateMarkerSet;

  const _EmptyState({
    required this.onCreateMarkerSet,
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
              Icons.bookmarks_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No Marker Sets Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Create a marker set to organize section markers for this track.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            FilledButton.icon(
              onPressed: onCreateMarkerSet,
              icon: const Icon(Icons.add),
              label: const Text('Create Marker Set'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with retry option
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
              'Error Loading Marker Sets',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            FilledButton.icon(
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
