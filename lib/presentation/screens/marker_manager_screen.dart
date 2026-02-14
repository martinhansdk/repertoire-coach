import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../domain/entities/marker_set.dart';
import '../providers/auth_provider.dart';
import '../providers/marker_provider.dart';
import 'marker_sync/marker_sync_screen.dart';
import '../widgets/marker_set_dialog.dart';

/// Marker Manager Screen
///
/// Manages marker sets and markers for a specific track.
/// Users can create, edit, and delete marker sets and markers.
class MarkerManagerScreen extends ConsumerWidget {
  final String trackId;
  final String trackName;
  final String songTitle;

  const MarkerManagerScreen({
    super.key,
    required this.trackId,
    required this.trackName,
    required this.songTitle,
  });

  Future<void> _navigateToMarkerSync(BuildContext context, WidgetRef ref) async {
    final markerSetId = await showDialog<String?>(
      context: context,
      builder: (context) => MarkerSetDialog(trackId: trackId),
    );

    if (markerSetId == null) {
      return;
    }

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarkerSyncScreen(
            trackId: trackId,
            markerSetId: markerSetId,
          ),
        ),
      );

      // Refresh marker sets after returning
      ref.invalidate(markerSetsByTrackProvider);
    }
  }

  Future<void> _deleteMarkerSet(
    BuildContext context,
    WidgetRef ref,
    String markerSetId,
    String markerSetName,
    String userId,
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
          ref.invalidate(markerSetsByTrackProvider((trackId, userId)));
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
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to manage marker sets.')),
      );
    }
    final markerSetsAsync = ref.watch(markerSetsByTrackProvider((trackId, userId)));

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
              songTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
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
              onCreateMarkerSet: () => _navigateToMarkerSync(context, ref),
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
                    userId,
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
        onPressed: () => _navigateToMarkerSync(context, ref),
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

  Future<void> _editMarkerSetName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: markerSet.name);
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    final isOwner = userId == markerSet.createdByUserId;
    bool isShared = markerSet.isShared;

    final result = await showDialog<({String name, bool isShared})?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Marker Set'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Share with choir'),
                subtitle: Text(
                  isOwner
                      ? (isShared
                          ? 'All choir members can see and edit'
                          : 'Only you can see and edit')
                      : 'Only the owner can change sharing',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: isShared,
                onChanged: isOwner
                    ? (value) {
                        setState(() {
                          isShared = value;
                        });
                      }
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (name: controller.text.trim(), isShared: isShared),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null &&
        result.name.isNotEmpty &&
        (result.name != markerSet.name || result.isShared != markerSet.isShared) &&
        context.mounted) {
      try {
        final repository = ref.read(markerRepositoryProvider);
        final updatedMarkerSet = MarkerSet(
          id: markerSet.id,
          trackId: markerSet.trackId,
          name: result.name,
          isShared: result.isShared,
          isTimeSynced: markerSet.isTimeSynced,
          createdByUserId: markerSet.createdByUserId,
          createdAt: markerSet.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.updateMarkerSet(updatedMarkerSet);

        if (context.mounted) {
          ref.invalidate(markerSetsByTrackProvider);

          // Show appropriate message based on what changed
          final message = result.isShared != markerSet.isShared
              ? result.isShared
                  ? 'Marker set shared with choir'
                  : 'Marker set made private'
              : 'Marker set updated';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating marker set: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _startSync(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkerSyncScreen(
          trackId: trackId,
          markerSetId: markerSet.id,
        ),
      ),
    );
  }

  Future<void> _startSyncFromExisting(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkerSyncScreen(
          trackId: trackId,
          markerSetId: markerSet.id,
          startInTimeSync: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final markersAsync = ref.watch(markersByMarkerSetProvider(markerSet.id));
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    final isOwner = userId == markerSet.createdByUserId;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(markerSet.name),
                  const SizedBox(height: 2),
                  Text(
                    '${markerSet.isTimeSynced ? 'Synced to audio' : 'Not synced to audio'} • ${isOwner ? 'Owned by you' : 'Shared with you'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit_text',
              child: Row(
                children: [
                  Icon(Icons.notes),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sync',
              child: Row(
                children: [
                  const Icon(Icons.sync),
                  const SizedBox(width: 8),
                  Text(markerSet.isTimeSynced ? 'Re-sync' : 'Sync'),
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
            if (value == 'rename') {
              _editMarkerSetName(context, ref);
            } else if (value == 'edit_text') {
              _startSync(context);
            } else if (value == 'sync') {
              _startSyncFromExisting(context);
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
                        onPressed: () => _startSync(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                );
              }

              final markerText = markers.map((marker) => marker.label).join('\n');

              return Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    markerText,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
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
