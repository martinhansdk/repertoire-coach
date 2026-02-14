import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/audio_player_provider.dart';
import '../../providers/marker_provider.dart';
import '../../providers/marker_sync_provider.dart';
import 'marker_sync_state.dart';
import 'text_input_step.dart';
import 'time_sync_step.dart';

/// Main screen for marker sync workflow
///
/// Coordinates between two steps:
/// 1. Text input - User enters marker labels
/// 2. Time sync - User syncs markers to audio positions
class MarkerSyncScreen extends ConsumerStatefulWidget {
  final String trackId;
  final String markerSetId;
  final bool startInTimeSync;

  const MarkerSyncScreen({
    super.key,
    required this.trackId,
    required this.markerSetId,
    this.startInTimeSync = false,
  });

  @override
  ConsumerState<MarkerSyncScreen> createState() => _MarkerSyncScreenState();
}

class _MarkerSyncScreenState extends ConsumerState<MarkerSyncScreen> {
  late final AudioPlayerControls _audioControls;
  bool _didInitFromExisting = false;

  @override
  void initState() {
    super.initState();
    _audioControls = ref.read(audioPlayerControlsProvider);
    _initializeTimeSyncIfRequested();
  }

  @override
  void dispose() {
    _audioControls.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create provider params
    final params = MarkerSyncParams(
      trackId: widget.trackId,
      markerSetId: widget.markerSetId,
    );

    // Watch state
    final state = ref.watch(markerSyncNotifierProvider(params));

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handlePopWithDiscard(context, ref, params);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sync Markers'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmDiscard(context, ref, state, params),
          ),
          actions: state.step == SyncStep.timeSync
              ? [
                  IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Restart sync',
                    onPressed: () => _showRestartConfirmation(context, ref, params),
                  ),
                ]
              : null,
        ),
        body: switch (state.step) {
          SyncStep.textInput => TextInputStep(params: params),
          SyncStep.timeSync => TimeSyncStep(params: params),
        },
      ),
    );
  }

  void _initializeTimeSyncIfRequested() {
    if (!widget.startInTimeSync || _didInitFromExisting) {
      return;
    }
    _didInitFromExisting = true;

    Future<void>(() async {
      if (!mounted) return;
      final params = MarkerSyncParams(
        trackId: widget.trackId,
        markerSetId: widget.markerSetId,
      );
      final state = ref.read(markerSyncNotifierProvider(params));
      if (state.step == SyncStep.timeSync) {
        return;
      }

      final repository = ref.read(markerRepositoryProvider);
      final markers = await repository.getMarkersByMarkerSet(widget.markerSetId);
      if (markers.isEmpty) {
        return;
      }

      final sorted = List.of(markers)..sort((a, b) => a.order.compareTo(b.order));
      final text = sorted.map((marker) => marker.label).join('\n');
      if (text.trim().isEmpty) {
        return;
      }

      // Use startSyncFromText to preserve existing timestamps when re-syncing
      await ref.read(markerSyncNotifierProvider(params).notifier).startSyncFromText(text);
    });
  }

  Future<void> _handlePopWithDiscard(
    BuildContext context,
    WidgetRef ref,
    MarkerSyncParams params,
  ) async {
    final shouldPop = await _showDiscardConfirmation(context, ref, params);
    if (shouldPop && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _confirmDiscard(
    BuildContext context,
    WidgetRef ref,
    MarkerSyncState state,
    MarkerSyncParams params,
  ) async {
    if (!state.isDirty) {
      Navigator.pop(context);
      return;
    }

    final shouldPop = await _showDiscardConfirmation(context, ref, params);
    if (shouldPop && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _showRestartConfirmation(
    BuildContext context,
    WidgetRef ref,
    MarkerSyncParams params,
  ) {
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
              ref.read(markerSyncNotifierProvider(params).notifier).restart();
              _audioControls.stop();
              Navigator.pop(context);
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDiscardConfirmation(
    BuildContext context,
    WidgetRef ref,
    MarkerSyncParams params,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved marker positions. Discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(markerSyncNotifierProvider(params).notifier).discard();
              Navigator.pop(context, true);
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
