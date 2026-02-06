import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/marker_sync_provider.dart';
import 'marker_sync_state.dart';
import 'text_input_step.dart';
import 'time_sync_step.dart';

/// Main screen for marker sync workflow
///
/// Coordinates between two steps:
/// 1. Text input - User enters marker labels
/// 2. Time sync - User syncs markers to audio positions
class MarkerSyncScreen extends ConsumerWidget {
  final String trackId;
  final String markerSetId;

  const MarkerSyncScreen({
    super.key,
    required this.trackId,
    required this.markerSetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Create provider params
    final params = MarkerSyncParams(
      trackId: trackId,
      markerSetId: markerSetId,
    );

    // Watch state
    final state = ref.watch(markerSyncNotifierProvider(params));

    return WillPopScope(
      onWillPop: () async {
        if (state.isDirty) {
          return await _showDiscardConfirmation(context, ref, params);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sync Markers'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmDiscard(context, ref, state, params),
          ),
        ),
        body: switch (state.step) {
          SyncStep.textInput => TextInputStep(params: params),
          SyncStep.timeSync => TimeSyncStep(params: params),
        },
      ),
    );
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
