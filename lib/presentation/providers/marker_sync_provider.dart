import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
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
      debugPrint('[MarkerSync] No non-empty lines found in input');
      return;
    }

    final nonEmptyCount = lines.where((l) => l.isNotEmpty).length;
    debugPrint('[MarkerSync] Parsed ${lines.length} lines ($nonEmptyCount non-empty)');

    state = state.copyWith(
      step: SyncStep.timeSync,
      labels: lines,
      currentIndex: -1, // Start at "..." marker
      syncedPositions: {-1: 0}, // "..." is always at 0:00.000
      isDirty: false, // Not dirty yet - no sync has happened
    );
  }

  /// Persist labels as an unsynced marker set and advance to sync step
  Future<void> startSyncFromText(String text) async {
    // Keep all lines including empty ones for visual organization
    final lines = text.split('\n').map((line) => line.trim()).toList();

    if (lines.every((line) => line.isEmpty)) {
      debugPrint('[MarkerSync] No non-empty lines found in input');
      return;
    }

    // Load existing markers to check if text changed
    final existingMarkers =
        await _markerRepository.getMarkersByMarkerSet(state.markerSetId);

    // Check if text changed
    final existingText = existingMarkers.map((m) => m.label).toList();
    final textChanged = existingText.length != lines.length ||
        !List.generate(lines.length, (i) => existingText[i] == lines[i]).every((e) => e);

    if (textChanged) {
      debugPrint('[MarkerSync] Text changed - updating database');

      // Update existing markers, create new ones, delete extras
      for (int i = 0; i < lines.length; i++) {
        final label = lines[i];
        if (i < existingMarkers.length) {
          final existing = existingMarkers[i];
          final updated = Marker(
            id: existing.id,
            markerSetId: existing.markerSetId,
            label: label,
            positionMs: existing.positionMs,
            order: i,
            createdAt: existing.createdAt,
          );
          await _markerRepository.updateMarker(updated);
        } else {
          final marker = Marker(
            id: const Uuid().v4(),
            markerSetId: state.markerSetId,
            label: label,
            positionMs: 0,
            order: i,
            createdAt: DateTime.now().toUtc(),
          );
          await _markerRepository.createMarker(marker);
        }
      }

      for (int i = lines.length; i < existingMarkers.length; i++) {
        await _markerRepository.deleteMarker(existingMarkers[i].id);
      }

      final markerSet = await _markerRepository.getMarkerSetById(state.markerSetId);
      if (markerSet != null) {
        await _markerRepository.updateMarkerSet(
          MarkerSet(
            id: markerSet.id,
            trackId: markerSet.trackId,
            name: markerSet.name,
            isShared: markerSet.isShared,
            isTimeSynced: false,
            createdByUserId: markerSet.createdByUserId,
            createdAt: markerSet.createdAt,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      setLabels(text);
    } else {
      debugPrint('[MarkerSync] Text unchanged - loading existing timestamps');

      // Text unchanged - load existing timestamps into state
      final syncedPositions = <int, int>{-1: 0}; // Start with "..." marker
      for (int i = 0; i < existingMarkers.length; i++) {
        syncedPositions[i] = existingMarkers[i].positionMs;
      }

      // Find the last synced marker
      int lastSyncedIndex = -1;
      for (int i = existingMarkers.length - 1; i >= 0; i--) {
        if (existingMarkers[i].label.isNotEmpty) {
          lastSyncedIndex = i;
          break;
        }
      }

      state = state.copyWith(
        step: SyncStep.timeSync,
        labels: lines,
        currentIndex: lastSyncedIndex,
        syncedPositions: syncedPositions,
        isDirty: false,
      );
    }
  }

  /// Sync the next non-empty marker to the given position
  void syncNextMarker(int positionMs) {
    debugPrint('[MarkerSync] syncNextMarker called: position=$positionMs, currentIndex=${state.currentIndex}');

    // If we're already at the last non-empty marker and it's synced, do nothing.
    int lastNonEmptyIndex = -1;
    for (int i = state.labels.length - 1; i >= 0; i--) {
      if (state.labels[i].isNotEmpty) {
        lastNonEmptyIndex = i;
        break;
      }
    }
    if (lastNonEmptyIndex != -1 &&
        state.currentIndex == lastNonEmptyIndex &&
        state.syncedPositions.containsKey(lastNonEmptyIndex)) {
      debugPrint('[MarkerSync] All markers already synced');
      return;
    }

    // If user jumped back and is resyncing, clear later timestamps only when syncing.
    final newPositions = {...state.syncedPositions};
    int lastSyncedIndex = -1;
    for (final entry in newPositions.entries) {
      if (entry.key >= 0 && entry.key > lastSyncedIndex) {
        lastSyncedIndex = entry.key;
      }
    }
    if (state.currentIndex < lastSyncedIndex) {
      newPositions.removeWhere((key, _) => key > state.currentIndex);
    }

    // Determine which marker to sync: next non-empty after current.
    int syncIndex = state.currentIndex + 1;
    if (syncIndex < 0) syncIndex = 0;
    while (syncIndex < state.labels.length && state.labels[syncIndex].isEmpty) {
      debugPrint('[MarkerSync] Skipping empty line at index $syncIndex');
      syncIndex++;
    }

    if (syncIndex >= state.labels.length) {
      debugPrint('[MarkerSync] No more non-empty markers to sync');
      return; // No more markers
    }

    // Verify monotonic invariant (should be prevented by UI, but double-check)
    int lastSyncedPosition = 0;
    for (final entry in newPositions.entries) {
      if (entry.value > lastSyncedPosition) {
        lastSyncedPosition = entry.value;
      }
    }
    if (positionMs < lastSyncedPosition) {
      debugPrint('[MarkerSync] ERROR: Position $positionMs < last synced $lastSyncedPosition (should be prevented by UI)');
      return; // Don't apply sync - this should never happen
    }

    debugPrint('[MarkerSync] Syncing marker at index $syncIndex ("${state.labels[syncIndex]}") to position $positionMs ms');

    // Apply position to the synced marker and any empty lines we skipped over.
    final startIndex = state.currentIndex == -1 ? 0 : state.currentIndex + 1;
    for (int i = startIndex; i <= syncIndex; i++) {
      newPositions[i] = positionMs;
      if (state.labels[i].isEmpty) {
        debugPrint('[MarkerSync] Syncing skipped empty line at index $i to position $positionMs ms');
      }
    }

    state = state.copyWith(
      syncedPositions: newPositions,
      currentIndex: syncIndex,
      isDirty: true,
    );
  }

  /// Jump to a specific marker (without applying position)
  void jumpToMarker(int index) {
    if (index < -1 || index >= state.labels.length) {
      debugPrint('[MarkerSync] Invalid jump to index $index');
      return;
    }

    debugPrint('[MarkerSync] Jumping to marker at index $index');

    state = state.copyWith(
      currentIndex: index,
    );
  }

  /// Restart sync process (clear all positions except "...")
  void restart() {
    debugPrint('[MarkerSync] Restarting sync - clearing all positions');

    state = state.copyWith(
      currentIndex: -1,
      syncedPositions: {-1: 0}, // Keep only "..." marker
      isDirty: true,
    );
  }

  /// Save all synced markers to the repository
  Future<void> save() async {
    debugPrint('[MarkerSync] Saving markers...');

    int savedCount = 0;
    int skippedEmpty = 0;
    int skippedUnsynced = 0;
    bool allNonEmptySynced = true;

    await _markerRepository.deleteMarkersByMarkerSet(state.markerSetId);

    // Create all synced non-empty markers in repository
    for (int i = 0; i < state.labels.length; i++) {
      final label = state.labels[i];

      if (label.isEmpty) {
        skippedEmpty++;
      }

      // If this non-empty marker has no synced position, track unsynced
      final positionMs = state.syncedPositions[i];
      if (positionMs == null) {
        if (label.isNotEmpty) {
          debugPrint('[MarkerSync] Saving unsynced marker: "$label"');
          skippedUnsynced++;
          allNonEmptySynced = false;
        }
      }

      final resolvedPosition = positionMs ?? 0;
      debugPrint('[MarkerSync] Creating marker: "$label" at $resolvedPosition ms');

      final marker = Marker(
        id: const Uuid().v4(),
        markerSetId: state.markerSetId,
        label: label,
        positionMs: resolvedPosition,
        order: i, // Preserve input order
        createdAt: DateTime.now().toUtc(),
      );

      await _markerRepository.createMarker(marker);
      savedCount++;
    }

    debugPrint('[MarkerSync] Save complete: $savedCount saved, $skippedUnsynced unsynced, $skippedEmpty empty lines');

    final markerSet = await _markerRepository.getMarkerSetById(state.markerSetId);
    if (markerSet != null) {
      await _markerRepository.updateMarkerSet(
        MarkerSet(
          id: markerSet.id,
          trackId: markerSet.trackId,
          name: markerSet.name,
          isShared: markerSet.isShared,
          isTimeSynced: allNonEmptySynced,
          createdByUserId: markerSet.createdByUserId,
          createdAt: markerSet.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    // Mark as saved (no longer dirty)
    state = state.copyWith(isDirty: false);
  }

  /// Discard all changes and reset to initial state
  void discard() {
    debugPrint('[MarkerSync] Discarding changes');
    state = state.copyWith(
      step: SyncStep.textInput,
      labels: const [],
      syncedPositions: const {},
      currentIndex: -1,
      isDirty: false,
    );
  }
}
