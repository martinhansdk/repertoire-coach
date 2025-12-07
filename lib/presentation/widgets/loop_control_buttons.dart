import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final position = ref.read(currentPlaybackProvider).position;
    setState(() {
      _loopPointA = position;
      if (_loopPointB != null && position >= _loopPointB!) {
        _loopPointB = null;
      }
    });
  }

  void _setLoopPointB() {
    final position = ref.read(currentPlaybackProvider).position;
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
    if (widget.markers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 markers to create a loop'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Sort markers by position
    final sortedMarkers = List<Marker>.from(widget.markers)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

    Marker? startMarker;
    Marker? endMarker;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Loop Between Markers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Marker',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Marker>(
                    value: startMarker,
                    isExpanded: true,
                    items: sortedMarkers.map((marker) {
                      return DropdownMenuItem(
                        value: marker,
                        child: Text(marker.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        startMarker = value;
                        // Reset end marker if it's now before start
                        if (endMarker != null &&
                            value != null &&
                            endMarker!.positionMs <= value.positionMs) {
                          endMarker = null;
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'End Marker',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Marker>(
                    value: endMarker,
                    isExpanded: true,
                    items: sortedMarkers
                        .where((m) =>
                            startMarker == null || m.positionMs > startMarker!.positionMs)
                        .map((marker) {
                      return DropdownMenuItem(
                        value: marker,
                        child: Text(marker.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        endMarker = value;
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
              onPressed: startMarker != null && endMarker != null
                  ? () async {
                      Navigator.of(context).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final loopControls = ref.read(loopControlsProvider);
                        await loopControls.setLoopFromMarkers(
                          startMarker!,
                          endMarker!,
                        );

                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Looping: ${startMarker!.label} → ${endMarker!.label}',
                              ),
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
                if (widget.markers.length >= 2)
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
