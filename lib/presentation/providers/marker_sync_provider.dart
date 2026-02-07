import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/marker.dart';
import '../../domain/repositories/marker_repository.dart';
import '../screens/marker_sync/marker_sync_state.dart';
import 'marker_provider.dart';

/// Provider for the marker sync state notifier
final markerSyncNotifierProvider =
    StateNotifierProvider.autoDispose.family<MarkerSyncNotifier, MarkerSyncState, MarkerSyncParams>(
  (ref, params) {
    return MarkerSyncNotifier(
      markerRepository: ref.watch(markerRepositoryProvider),
      trackId: params.trackId,
      markerSetId: params.markerSetId,
    );
  },
);

/// Parameters for creating a marker sync notifier
class MarkerSyncParams {
  final String trackId;
  final String markerSetId;

  const MarkerSyncParams({
    required this.trackId,
    required this.markerSetId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkerSyncParams &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId &&
          markerSetId == other.markerSetId;

  @override
  int get hashCode => trackId.hashCode ^ markerSetId.hashCode;
}

/// State notifier for marker sync workflow
class MarkerSyncNotifier extends StateNotifier<MarkerSyncState> {
  final MarkerRepository _markerRepository;

  MarkerSyncNotifier({
    required MarkerRepository markerRepository,
    required String trackId,
    required String markerSetId,
  })  : _markerRepository = markerRepository,
        super(MarkerSyncState.initial(
          trackId: trackId,
          markerSetId: markerSetId,
        ));

  /// Parse text input into marker labels and advance to sync step
  void setLabels(String text) {
    // Keep all lines including empty ones for visual organization
    final lines = text.split('\n').map((line) => line.trim()).toList();

    // Need at least one non-empty line
    if (lines.every((line) => line.isEmpty)) {
      print('[MarkerSync] No non-empty lines found in input');
      return;
    }

    final nonEmptyCount = lines.where((l) => l.isNotEmpty).length;
    print('[MarkerSync] Parsed ${lines.length} lines ($nonEmptyCount non-empty)');

    state = state.copyWith(
      step: SyncStep.timeSync,
      labels: lines,
      currentIndex: -1, // Start at "..." marker
      syncedPositions: {-1: 0}, // "..." is always at 0:00.000
      isDirty: false, // Not dirty yet - no sync has happened
    );
  }

  /// Sync the next non-empty marker to the given position
  void syncNextMarker(int positionMs) {
    print('[MarkerSync] syncNextMarker called: position=$positionMs, currentIndex=${state.currentIndex}');

    // Determine which marker to sync.
    int syncIndex = state.currentIndex == -1 ? 0 : state.currentIndex;
    if (syncIndex < 0) {
      syncIndex = 0;
    }
    while (syncIndex < state.labels.length && state.labels[syncIndex].isEmpty) {
      print('[MarkerSync] Skipping empty line at index $syncIndex');
      syncIndex++;
    }

    if (syncIndex >= state.labels.length) {
      print('[MarkerSync] No more non-empty markers to sync');
      return; // No more markers
    }

    // Verify monotonic invariant (should be prevented by UI, but double-check)
    final lastSyncedPosition = state.getLastSyncedPosition();
    if (positionMs < lastSyncedPosition) {
      print('[MarkerSync] ERROR: Position $positionMs < last synced $lastSyncedPosition (should be prevented by UI)');
      return; // Don't apply sync - this should never happen
    }

    print('[MarkerSync] Syncing marker at index $syncIndex ("${state.labels[syncIndex]}") to position $positionMs ms');

    // Apply position to next marker and any skipped empty lines
    final newPositions = {...state.syncedPositions};
    final startIndex = state.currentIndex == -1 ? 0 : state.currentIndex;
    for (int i = startIndex; i <= syncIndex; i++) {
      newPositions[i] = positionMs;
      if (state.labels[i].isEmpty) {
        print('[MarkerSync] Syncing skipped empty line at index $i to position $positionMs ms');
      }
    }

    // Advance to the next non-empty marker after the one just synced.
    int nextIndex = syncIndex + 1;
    while (nextIndex < state.labels.length && state.labels[nextIndex].isEmpty) {
      nextIndex++;
    }
    final newCurrentIndex = nextIndex < state.labels.length ? nextIndex : syncIndex;

    state = state.copyWith(
      syncedPositions: newPositions,
      currentIndex: newCurrentIndex,
      isDirty: true,
    );
  }

  /// Jump to a specific marker (without applying position)
  void jumpToMarker(int index) {
    if (index < -1 || index >= state.labels.length) {
      print('[MarkerSync] Invalid jump to index $index');
      return;
    }

    print('[MarkerSync] Jumping to marker at index $index');

    state = state.copyWith(
      currentIndex: index,
    );
  }

  /// Restart sync process (clear all positions except "...")
  void restart() {
    print('[MarkerSync] Restarting sync - clearing all positions');

    state = state.copyWith(
      currentIndex: -1,
      syncedPositions: {-1: 0}, // Keep only "..." marker
      isDirty: true,
    );
  }

  /// Save all synced markers to the repository
  Future<void> save() async {
    print('[MarkerSync] Saving markers...');

    int savedCount = 0;
    int skippedEmpty = 0;
    int skippedUnsynced = 0;

    // Create all synced non-empty markers in repository
    for (int i = 0; i < state.labels.length; i++) {
      final label = state.labels[i];

      // Skip empty lines
      if (label.isEmpty) {
        skippedEmpty++;
        continue;
      }

      // Skip unsynced markers (unsynced is valid - user's choice)
      final positionMs = state.syncedPositions[i];
      if (positionMs == null) {
        print('[MarkerSync] Skipping unsynced marker: "$label"');
        skippedUnsynced++;
        continue;
      }

      print('[MarkerSync] Creating marker: "$label" at $positionMs ms');

      final marker = Marker(
        id: const Uuid().v4(),
        markerSetId: state.markerSetId,
        label: label,
        positionMs: positionMs,
        order: positionMs, // Chronological order
        createdAt: DateTime.now().toUtc(),
      );

      await _markerRepository.createMarker(marker);
      savedCount++;
    }

    print('[MarkerSync] Save complete: $savedCount saved, $skippedUnsynced unsynced, $skippedEmpty empty lines');

    // Mark as saved (no longer dirty)
    state = state.copyWith(isDirty: false);
  }

  /// Discard all changes and reset to initial state
  void discard() {
    print('[MarkerSync] Discarding changes');
    state = MarkerSyncState.initial(
      trackId: state.trackId,
      markerSetId: state.markerSetId,
    );
  }
}
