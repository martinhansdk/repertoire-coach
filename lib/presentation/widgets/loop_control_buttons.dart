import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/loop_range.dart';
import '../../domain/entities/marker.dart';
import '../providers/audio_player_provider.dart';
import '../providers/loop_control_provider.dart';

/// Control buttons for A-B loop functionality
///
/// Provides buttons to set loop points and clear loops.
/// Displays current loop range information.
class LoopControlButtons extends ConsumerStatefulWidget {
  final List<Marker> markers;

  const LoopControlButtons({
    super.key,
    required this.markers,
  });

  @override
  ConsumerState<LoopControlButtons> createState() => _LoopControlButtonsState();
}

class _LoopControlButtonsState extends ConsumerState<LoopControlButtons> {
  Duration? _loopPointA;
  Duration? _loopPointB;

  void _setLoopPointA() {
    // Read directly from repository to get live position (not cached)
    final repository = ref.read(audioPlayerRepositoryProvider);
    final position = repository.currentPlayback.position;
    setState(() {
      _loopPointA = position;
      if (_loopPointB != null && position >= _loopPointB!) {
        _loopPointB = null;
      }
    });
  }

  void _setLoopPointB() {
    // Read directly from repository to get live position (not cached)
    final repository = ref.read(audioPlayerRepositoryProvider);
    final position = repository.currentPlayback.position;
    if (_loopPointA == null || position <= _loopPointA!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Point B must be after Point A'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _loopPointB = position;
    });

    // Automatically create loop when both points are set
    _createLoop();
  }

  Future<void> _createLoop() async {
    if (_loopPointA == null || _loopPointB == null) {
      return;
    }

    try {
      final loopControls = ref.read(loopControlsProvider);
      await loopControls.setCustomLoop(
        startPosition: _loopPointA!,
        endPosition: _loopPointB!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loop activated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating loop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearLoop() async {
    try {
      final loopControls = ref.read(loopControlsProvider);
      await loopControls.clearLoop();

      setState(() {
        _loopPointA = null;
        _loopPointB = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loop cleared'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing loop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showMarkerLoopDialog() async {
    if (widget.markers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 1 marker to create a loop'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Sort markers by position
    final sortedMarkers = List<Marker>.from(widget.markers)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

    // Get current position for "Current Position" option
    final repository = ref.read(audioPlayerRepositoryProvider);
    final currentPosition = repository.currentPlayback.position;

    // Track selection as either marker or 'current'
    String? startSelection; // 'current' or marker.id
    String? endSelection; // 'current' or marker.id

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Loop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start point selector
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Loop Start',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: startSelection,
                    isExpanded: true,
                    hint: const Text('Select start point'),
                    items: [
                      const DropdownMenuItem(
                        value: 'current',
                        child: Row(
                          children: [
                            Icon(Icons.my_location, size: 16),
                            SizedBox(width: 8),
                            Text('Current Position'),
                          ],
                        ),
                      ),
                      ...sortedMarkers.map((marker) {
                        return DropdownMenuItem(
                          value: marker.id,
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark, size: 16),
                              const SizedBox(width: 8),
                              Text(marker.label),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        startSelection = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // End point selector
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Loop End',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: endSelection,
                    isExpanded: true,
                    hint: const Text('Select end point'),
                    items: [
                      const DropdownMenuItem(
                        value: 'current',
                        child: Row(
                          children: [
                            Icon(Icons.my_location, size: 16),
                            SizedBox(width: 8),
                            Text('Current Position'),
                          ],
                        ),
                      ),
                      ...sortedMarkers.map((marker) {
                        return DropdownMenuItem(
                          value: marker.id,
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark, size: 16),
                              const SizedBox(width: 8),
                              Text(marker.label),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        endSelection = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: startSelection != null && endSelection != null
                  ? () async {
                      Navigator.of(context).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        // Determine start and end positions
                        final Duration startPos;
                        final String startLabel;
                        if (startSelection == 'current') {
                          startPos = currentPosition;
                          startLabel = _formatDuration(currentPosition);
                        } else {
                          final marker = sortedMarkers.firstWhere((m) => m.id == startSelection);
                          startPos = Duration(milliseconds: marker.positionMs);
                          startLabel = marker.label;
                        }

                        final Duration endPos;
                        final String endLabel;
                        if (endSelection == 'current') {
                          endPos = currentPosition;
                          endLabel = _formatDuration(currentPosition);
                        } else {
                          final marker = sortedMarkers.firstWhere((m) => m.id == endSelection);
                          endPos = Duration(milliseconds: marker.positionMs);
                          endLabel = marker.label;
                        }

                        // Validate positions
                        if (endPos <= startPos) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('End position must be after start position'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }

                        // Create the loop range
                        final loopRange = LoopRange(
                          startPosition: startPos,
                          endPosition: endPos,
                          startMarkerId: startSelection == 'current' ? null : startSelection,
                          endMarkerId: endSelection == 'current' ? null : endSelection,
                        );

                        // Set the loop
                        final repository = ref.read(audioPlayerRepositoryProvider);
                        await repository.setLoopRange(loopRange);

                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Looping: $startLabel → $endLabel'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error creating loop: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('Create Loop'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackInfo = ref.watch(playbackInfoProvider).value;
    final loopRange = playbackInfo?.loopRange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A-B Loop',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            // Loop status
            if (loopRange != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Loop: ${_formatDuration(loopRange.startPosition)} → ${_formatDuration(loopRange.endPosition)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'No loop active',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 12),

            // Control buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _setLoopPointA,
                  icon: const Icon(Icons.start),
                  label: Text(_loopPointA != null
                      ? 'A: ${_formatDuration(_loopPointA!)}'
                      : 'Set Point A'),
                  style: _loopPointA != null
                      ? OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                OutlinedButton.icon(
                  onPressed: _loopPointA != null ? _setLoopPointB : null,
                  icon: const Icon(Icons.stop),
                  label: Text(_loopPointB != null
                      ? 'B: ${_formatDuration(_loopPointB!)}'
                      : 'Set Point B'),
                  style: _loopPointB != null
                      ? OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        )
                      : null,
                ),
                if (widget.markers.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _showMarkerLoopDialog,
                    icon: const Icon(Icons.bookmarks),
                    label: const Text('From Markers'),
                  ),
                if (loopRange != null)
                  OutlinedButton.icon(
                    onPressed: _clearLoop,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Loop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
