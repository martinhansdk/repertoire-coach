import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/marker_invariant_exception.dart';
import '../../../domain/entities/audio_player_state.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/marker_provider.dart';
import '../../providers/marker_sync_provider.dart';
import '../../providers/track_provider.dart';
import 'marker_sync_state.dart';

/// Step 2 of marker sync: User syncs markers to audio positions
class TimeSyncStep extends ConsumerStatefulWidget {
  final MarkerSyncParams params;

  const TimeSyncStep({super.key, required this.params});

  @override
  ConsumerState<TimeSyncStep> createState() => _TimeSyncStepState();
}

class _TimeSyncStepState extends ConsumerState<TimeSyncStep> {
  final _scrollController = ScrollController();
  bool _didResetPlayback = false;
  bool _isSaving = false;
  static const double _markerItemExtent = 64.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resetPlaybackPosition() async {
    if (_didResetPlayback) return;
    _didResetPlayback = true;

    final playbackInfo = ref.read(currentPlaybackProvider);
    final audioControls = ref.read(audioPlayerControlsProvider);

    if (playbackInfo.currentTrack?.id == widget.params.trackId) {
      await audioControls.pause();
      await audioControls.seek(Duration.zero);
    } else {
      await audioControls.stop();
    }
  }

  void _scrollToCurrentMarker() {
    final state = ref.read(markerSyncNotifierProvider(widget.params));
    if (!mounted) return;

    if (!_scrollController.hasClients) return;
    final markerIndex = state.currentIndex + 1; // +1 because "..." is at index 0
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset =
        (markerIndex * _markerItemExtent) - (viewportHeight / 2) + (_markerItemExtent / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _syncNextMarker() {
    final repository = ref.read(audioPlayerRepositoryProvider);
    final position = repository.currentPlayback.position;
    ref.read(markerSyncNotifierProvider(widget.params).notifier).syncNextMarker(position.inMilliseconds);
  }

  void _showRestartConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart sync?'),
        content: const Text('This will clear all synced positions and start from the beginning.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(markerSyncNotifierProvider(widget.params).notifier).restart();
              _didResetPlayback = false;
              _resetPlaybackPosition();
              Navigator.pop(context);
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await ref.read(markerSyncNotifierProvider(widget.params).notifier).save();
      // Invalidate marker caches to refresh parent screen
      ref.invalidate(markersByMarkerSetProvider);
      ref.invalidate(markerSetByIdProvider);
      ref.invalidate(markerSetsByTrackProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } on MarkerInvariantException catch (e) {
      debugPrint('[MarkerSync] Invariant violation while saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(MarkerInvariantException.userMessage)),
        );
      }
    } catch (e) {
      debugPrint('[MarkerSync] Unexpected save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save markers. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _editMarkerLabel(int markerIndex) async {
    final state = ref.read(markerSyncNotifierProvider(widget.params));
    if (markerIndex < 0 || markerIndex >= state.labels.length) return;

    final controller = TextEditingController(text: state.labels[markerIndex]);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit marker'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newLabel == null || !mounted) return;
    ref.read(markerSyncNotifierProvider(widget.params).notifier).updateLabel(markerIndex, newLabel);
  }

  void _showMarkerEditMenu(int markerIndex, bool isSynced) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit label'),
              onTap: () {
                Navigator.pop(context);
                _editMarkerLabel(markerIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add marker'),
              onTap: () {
                Navigator.pop(context);
                final notifier = ref.read(markerSyncNotifierProvider(widget.params).notifier);
                notifier.addMarkerAfter(markerIndex, label: 'New marker');
                _editMarkerLabel(markerIndex + 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Clear synced time'),
              enabled: isSynced,
              onTap: isSynced
                  ? () {
                      Navigator.pop(context);
                      ref
                          .read(markerSyncNotifierProvider(widget.params).notifier)
                          .clearSyncedPosition(markerIndex);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete marker'),
              onTap: () {
                Navigator.pop(context);
                ref.read(markerSyncNotifierProvider(widget.params).notifier).deleteMarker(markerIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _discard() {
    ref.read(markerSyncNotifierProvider(widget.params).notifier).discard();
    // Invalidate marker caches so parent screen reloads from database
    ref.invalidate(markersByMarkerSetProvider);
    ref.invalidate(markerSetByIdProvider);
    ref.invalidate(markerSetsByTrackProvider);
    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final ms = duration.inMilliseconds % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(markerSyncNotifierProvider(widget.params));
    final playbackInfoAsync = ref.watch(playbackInfoProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetPlaybackPosition();
    });
    ref.listen<MarkerSyncState>(
      markerSyncNotifierProvider(widget.params),
      (previous, next) {
        if (previous?.currentIndex != next.currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentMarker();
          });
        }
      },
    );

    // Check if sync button should be enabled
    final currentPositionMs = playbackInfoAsync.value?.position.inMilliseconds ?? 0;
    final lastSyncedPositionMs = state.getLastSyncedPositionUpTo(state.currentIndex);
    final canSync = !state.isComplete && currentPositionMs >= lastSyncedPositionMs;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const _SyncNextMarkerIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextMarkerIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousMarkerIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyR): const _RestartSyncIntent(),
      },
      child: Actions(
        actions: {
          _SyncNextMarkerIntent: CallbackAction<_SyncNextMarkerIntent>(
            onInvoke: (_) {
              if (canSync) _syncNextMarker();
              return null;
            },
          ),
          _NextMarkerIntent: CallbackAction<_NextMarkerIntent>(
            onInvoke: (_) {
              // Find next non-empty marker
              int nextIndex = state.currentIndex + 1;
              while (nextIndex < state.labels.length && state.labels[nextIndex].isEmpty) {
                nextIndex++;
              }
              if (nextIndex < state.labels.length) {
                ref.read(markerSyncNotifierProvider(widget.params).notifier).jumpToMarker(nextIndex);
              }
              return null;
            },
          ),
          _PreviousMarkerIntent: CallbackAction<_PreviousMarkerIntent>(
            onInvoke: (_) {
              // Find previous non-empty marker
              int prevIndex = state.currentIndex - 1;
              while (prevIndex >= -1 && prevIndex < state.labels.length &&
                     (prevIndex >= 0 && state.labels[prevIndex].isEmpty)) {
                prevIndex--;
              }
              if (prevIndex >= -1) {
                ref.read(markerSyncNotifierProvider(widget.params).notifier).jumpToMarker(prevIndex);
              }
              return null;
            },
          ),
          _RestartSyncIntent: CallbackAction<_RestartSyncIntent>(
            onInvoke: (_) {
              _showRestartConfirmation();
              return null;
            },
          ),
        },
        child: SafeArea(
          top: false,
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                // Audio player controls
                _buildAudioControls(theme, playbackInfoAsync),

                const Divider(),

                // Marker list
                Expanded(
                  child: ClipRect(
                    child: _buildMarkerList(theme, state),
                  ),
                ),

                const Divider(),

                // Action buttons
                _buildActionButtons(theme, canSync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioControls(ThemeData theme, AsyncValue playbackInfoAsync) {
    return playbackInfoAsync.when(
      data: (playbackInfo) {
        final audioControls = ref.read(audioPlayerControlsProvider);
        final isSyncTrack = playbackInfo.currentTrack?.id == widget.params.trackId;
        final displayInfo = isSyncTrack
            ? playbackInfo
            : playbackInfo.copyWith(
                clearTrack: true,
                state: AudioPlayerState.paused,
                position: Duration.zero,
                duration: Duration.zero,
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Compact time display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(displayInfo.position),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _formatDuration(displayInfo.duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10s
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () async {
                      final newPosition = displayInfo.position - const Duration(seconds: 10);
                      await audioControls.seek(newPosition.isNegative ? Duration.zero : newPosition);
                    },
                    tooltip: 'Rewind 10 seconds',
                  ),

                  const SizedBox(width: 16),

                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      displayInfo.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 40,
                    ),
                    onPressed: () async {
                      if (displayInfo.isPlaying) {
                        await audioControls.pause();
                      } else {
                        if (!isSyncTrack) {
                          final track = await ref.read(
                            trackByIdProvider(widget.params.trackId).future,
                          );
                          if (track == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Track not available for playback'),
                                ),
                              );
                            }
                            return;
                          }
                          try {
                            await audioControls.playTrack(track);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unable to start playback: $e'),
                                ),
                              );
                            }
                            return;
                          }
                        } else {
                          if (!_didResetPlayback) {
                            await _resetPlaybackPosition();
                          }
                          await audioControls.resume();
                        }
                      }
                    },
                    tooltip: displayInfo.isPlaying ? 'Pause' : 'Play',
                  ),

                  const SizedBox(width: 16),

                  // Forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () async {
                      final newPosition = displayInfo.position + const Duration(seconds: 10);
                      final maxPosition = displayInfo.duration;
                      await audioControls.seek(
                        newPosition > maxPosition ? maxPosition : newPosition,
                      );
                    },
                    tooltip: 'Forward 10 seconds',
                  ),

                  const SizedBox(width: 16),

                  // Restart sync
                  IconButton(
                    key: const ValueKey('markerSyncRestartButton'),
                    icon: const Icon(Icons.restart_alt),
                    onPressed: _showRestartConfirmation,
                    tooltip: 'Restart sync (clear all positions)',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progress bar (seekable)
              Builder(
                builder: (context) {
                  final maxMs = displayInfo.duration.inMilliseconds;
                  if (maxMs <= 0) {
                    return Slider(
                      value: 0,
                      max: 1,
                      onChanged: null,
                    );
                  }
                  final positionMs = displayInfo.position.inMilliseconds.clamp(0, maxMs);
                  return Slider(
                    value: positionMs.toDouble(),
                    max: maxMs.toDouble(),
                    onChanged: (value) async {
                      await audioControls.seek(Duration(milliseconds: value.toInt()));
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMarkerList(ThemeData theme, MarkerSyncState state) {
    return ListView.builder(
      controller: _scrollController,
      itemExtent: _markerItemExtent,
      itemCount: state.labels.length + 1, // +1 for leading "..." marker
      itemBuilder: (context, index) {
        final markerIndex = index - 1; // -1 = leading "..." marker

        // Special "..." marker at start
        if (markerIndex == -1) {
          return ListTile(
            key: const ValueKey('markerSyncMarker_-1'),
            selected: state.currentIndex == -1,
            leading: const Icon(Icons.check, color: Colors.green),
            title: const Text('...'),
            subtitle: const Text('0:00.000'),
            onTap: () {
              ref.read(markerSyncNotifierProvider(widget.params).notifier).jumpToMarker(-1);
              ref.read(audioPlayerControlsProvider).seek(Duration.zero);
            },
          );
        }

        final label = state.labels[markerIndex];

        // Empty line - render as spacing
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }

        // Non-empty marker
        final isSelected = state.currentIndex == markerIndex;
        final positionMs = state.getPositionForIndex(markerIndex);
        final isSynced = positionMs != null;

        return ListTile(
          key: ValueKey('markerSyncMarker_$markerIndex'),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          leading: Icon(
            isSynced ? Icons.check : Icons.pending,
            color: isSynced ? Colors.green : Colors.grey,
          ),
          title: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isSelected
                ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
                : null,
          ),
          subtitle: Text(
            isSynced
                ? _formatDuration(Duration(milliseconds: positionMs))
                : 'not synced',
            style: TextStyle(
              color: isSynced ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () {
            ref.read(markerSyncNotifierProvider(widget.params).notifier).jumpToMarker(markerIndex);
            if (isSynced) {
              ref
                  .read(audioPlayerControlsProvider)
                  .seek(Duration(milliseconds: positionMs));
            }
          },
          onLongPress: () => _showMarkerEditMenu(markerIndex, isSynced),
        );
      },
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool canSync) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        children: [
          // Sync button (prominent)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('markerSyncMarkHereButton'),
              onPressed: canSync ? _syncNextMarker : null,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Mark Here (Space)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(20),
                textStyle: theme.textTheme.titleMedium,
              ),
            ),
          ),

          if (!canSync) ...[
            const SizedBox(height: 8),
            Text(
              'Move forward in time to sync the next marker',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // Save/Discard buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('markerSyncDiscardButton'),
                  onPressed: _isSaving ? null : _discard,
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('markerSyncSaveButton'),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Intent classes for keyboard shortcuts
class _SyncNextMarkerIntent extends Intent {
  const _SyncNextMarkerIntent();
}

class _NextMarkerIntent extends Intent {
  const _NextMarkerIntent();
}

class _PreviousMarkerIntent extends Intent {
  const _PreviousMarkerIntent();
}

class _RestartSyncIntent extends Intent {
  const _RestartSyncIntent();
}
