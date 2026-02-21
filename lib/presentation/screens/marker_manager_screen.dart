import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
import '../../domain/entities/track.dart';
import '../providers/auth_provider.dart';
import '../providers/concert_provider.dart';
import '../providers/marker_provider.dart';
import '../providers/song_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/track_provider.dart';
import 'marker_sync/marker_sync_screen.dart';
import '../widgets/marker_label_markup.dart';
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

  Future<void> _copyMarkerSetFromTrack(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    final source = await _showCopyMarkerSetDialog(context, ref, userId);
    if (source == null || !context.mounted) return;

    final now = DateTime.now().toUtc();
    final repository = ref.read(markerRepositoryProvider);
    final newMarkerSetId = const Uuid().v4();

    final copiedSet = MarkerSet(
      id: newMarkerSetId,
      trackId: trackId,
      name: source.newName,
      isShared: source.markerSet.isShared,
      isTimeSynced: source.markerSet.isTimeSynced,
      createdByUserId: userId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await repository.createMarkerSet(copiedSet);

      final sourceMarkers = await repository.getMarkersByMarkerSet(source.markerSet.id);
      final sortedSourceMarkers = List<Marker>.from(sourceMarkers)
        ..sort((a, b) => a.order.compareTo(b.order));

      for (int i = 0; i < sortedSourceMarkers.length; i++) {
        final marker = sortedSourceMarkers[i];
        await repository.createMarker(
          Marker(
            id: const Uuid().v4(),
            markerSetId: newMarkerSetId,
            label: marker.label,
            positionMs: marker.positionMs,
            order: i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (context.mounted) {
        ref.invalidate(markerSetsByTrackProvider((trackId, userId)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "${source.markerSet.name}" to "$trackName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying marker set: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<_TrackWithContext>> _loadSameChoirTracks(
    WidgetRef ref,
  ) async {
    final trackRepository = ref.read(trackRepositoryProvider);
    final songRepository = ref.read(songRepositoryProvider);
    final concertRepository = ref.read(concertRepositoryProvider);

    final currentTrack = await trackRepository.getTrackById(trackId);
    if (currentTrack == null) return [];

    final currentSong = await songRepository.getSongById(currentTrack.songId);
    if (currentSong == null) return [];

    final currentConcert = await concertRepository.getConcertById(currentSong.concertId);
    if (currentConcert == null) return [];

    final choirConcerts = await concertRepository.getConcertsByChoir(currentConcert.choirId);
    final tracksWithContext = <_TrackWithContext>[];

    for (final concert in choirConcerts) {
      final songs = await songRepository.getSongsByConcert(concert.id);
      for (final song in songs) {
        final tracks = await trackRepository.getTracksBySong(song.id);
        for (final track in tracks) {
          if (track.id == trackId) continue;
          tracksWithContext.add(
            _TrackWithContext(
              track: track,
              songTitle: song.title,
              concertName: concert.name,
            ),
          );
        }
      }
    }

    tracksWithContext.sort((a, b) {
      final concertCompare = a.concertName.toLowerCase().compareTo(b.concertName.toLowerCase());
      if (concertCompare != 0) return concertCompare;
      final songCompare = a.songTitle.toLowerCase().compareTo(b.songTitle.toLowerCase());
      if (songCompare != 0) return songCompare;
      return a.track.name.toLowerCase().compareTo(b.track.name.toLowerCase());
    });

    return tracksWithContext;
  }

  Future<_MarkerSetCopySelection?> _showCopyMarkerSetDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final trackOptions = await _loadSameChoirTracks(ref);
    if (!context.mounted) return null;

    if (trackOptions.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Source Tracks'),
          content: const Text(
            'No other tracks were found in this choir. '
            'Create or sync markers on another track first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }

    final markerRepository = ref.read(markerRepositoryProvider);
    _TrackWithContext? selectedTrack;
    MarkerSet? selectedMarkerSet;
    List<MarkerSet> sourceMarkerSets = [];
    bool isLoadingSets = false;
    final nameController = TextEditingController();

    return showDialog<_MarkerSetCopySelection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> loadMarkerSets(_TrackWithContext track) async {
            setState(() {
              isLoadingSets = true;
              sourceMarkerSets = [];
              selectedMarkerSet = null;
              nameController.clear();
            });

            final sets = await markerRepository.getMarkerSetsByTrack(
              track.track.id,
              userId: userId,
            );
            if (!context.mounted) return;
            setState(() {
              sourceMarkerSets = sets;
              isLoadingSets = false;
            });
          }

          final canCopy = selectedTrack != null &&
              selectedMarkerSet != null &&
              nameController.text.trim().isNotEmpty;

          return AlertDialog(
            title: const Text('Copy Marker Set From Track'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<_TrackWithContext>(
                    key: const ValueKey('copyMarkerSetTrackDropdown'),
                    value: selectedTrack,
                    decoration: const InputDecoration(
                      labelText: 'Source Track',
                      border: OutlineInputBorder(),
                    ),
                    items: trackOptions
                        .map(
                          (option) => DropdownMenuItem<_TrackWithContext>(
                            value: option,
                            child: Text(
                              '${option.concertName} / ${option.songTitle} / ${option.track.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (_TrackWithContext? value) {
                      if (value == null) return;
                      setState(() {
                        selectedTrack = value;
                      });
                      loadMarkerSets(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MarkerSet>(
                    key: const ValueKey('copyMarkerSetSourceSetDropdown'),
                    value: selectedMarkerSet,
                    decoration: const InputDecoration(
                      labelText: 'Source Marker Set',
                      border: OutlineInputBorder(),
                    ),
                    items: sourceMarkerSets
                        .map(
                          (set) => DropdownMenuItem<MarkerSet>(
                            value: set,
                            child: Text(set.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: isLoadingSets
                        ? null
                        : (MarkerSet? value) {
                            setState(() {
                              selectedMarkerSet = value;
                              nameController.text = value?.name ?? '';
                            });
                          },
                  ),
                  if (isLoadingSets) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (!isLoadingSets && selectedTrack != null && sourceMarkerSets.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No marker sets found on selected track.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('copyMarkerSetNameField'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'New Marker Set Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('copyMarkerSetConfirmButton'),
                onPressed: canCopy
                    ? () => Navigator.pop(
                        context,
                        _MarkerSetCopySelection(
                          markerSet: selectedMarkerSet!,
                          newName: nameController.text.trim(),
                        ),
                      )
                    : null,
                child: const Text('Copy'),
              ),
            ],
          );
        },
      ),
    );
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

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
              onCopyFromTrack: () => _copyMarkerSetFromTrack(context, ref),
            );
          }

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.paddingMedium,
                    AppConstants.paddingSmall,
                    AppConstants.paddingMedium,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('copyMarkerSetButton'),
                      onPressed: () => _copyMarkerSetFromTrack(context, ref),
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copy From Track'),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      try {
                        await ref.read(syncControllerProvider.notifier).syncFromRemote();
                      } catch (_) {
                        // Keep pull-to-refresh functional in offline/test environments.
                      } finally {
                        ref.invalidate(markerSetsByTrackProvider((trackId, userId)));
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
                  ),
                ),
              ],
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

class _TrackWithContext {
  final Track track;
  final String songTitle;
  final String concertName;

  const _TrackWithContext({
    required this.track,
    required this.songTitle,
    required this.concertName,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other is _TrackWithContext && other.track.id == track.id);
  }

  @override
  int get hashCode => track.id.hashCode;
}

class _MarkerSetCopySelection {
  final MarkerSet markerSet;
  final String newName;

  const _MarkerSetCopySelection({
    required this.markerSet,
    required this.newName,
  });
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

              final markerLabels = markers
                  .map((marker) => MarkerLabelMarkup.parse(marker.label, stripSyntax: true))
                  .toList();

              return Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        for (int i = 0; i < markerLabels.length; i++) ...[
                          TextSpan(
                            text: markerLabels[i].displayText,
                            style: markerLabels[i].applyStyle(theme.textTheme.bodyMedium),
                          ),
                          if (i < markerLabels.length - 1)
                            TextSpan(
                              text: '\n',
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                      ],
                    ),
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
  final VoidCallback onCopyFromTrack;

  const _EmptyState({
    required this.onCreateMarkerSet,
    required this.onCopyFromTrack,
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
            const SizedBox(height: AppConstants.paddingSmall),
            OutlinedButton.icon(
              key: const ValueKey('copyMarkerSetButton'),
              onPressed: onCopyFromTrack,
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy From Track'),
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
