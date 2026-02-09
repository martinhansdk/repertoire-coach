import 'package:equatable/equatable.dart';

/// The current step in the marker sync workflow
enum SyncStep {
  /// Step 1: User inputs text (one marker per line)
  textInput,

  /// Step 2: User syncs markers to audio positions
  timeSync,
}

/// State for the marker sync workflow
class MarkerSyncState extends Equatable {
  /// Current step in the workflow
  final SyncStep step;

  /// ID of the track being synced
  final String trackId;

  /// ID of the marker set being created/edited
  final String markerSetId;

  /// List of marker labels from text input (including empty lines for visual spacing)
  final List<String> labels;

  /// Map of marker index to position in milliseconds
  /// Index -1 is the special "..." marker at 0:00.000
  final Map<int, int> syncedPositions;

  /// Index of currently highlighted marker (-1 = "..." marker)
  final int currentIndex;

  /// Whether there are unsaved changes
  final bool isDirty;

  const MarkerSyncState({
    required this.step,
    required this.trackId,
    required this.markerSetId,
    required this.labels,
    required this.syncedPositions,
    required this.currentIndex,
    required this.isDirty,
  });

  /// Initial state for a new marker sync workflow
  factory MarkerSyncState.initial({
    String? trackId,
    String? markerSetId,
  }) {
    return MarkerSyncState(
      step: SyncStep.textInput,
      trackId: trackId ?? '',
      markerSetId: markerSetId ?? '',
      labels: const [],
      syncedPositions: const {},
      currentIndex: -1,
      isDirty: false,
    );
  }

  /// Whether all non-empty markers have been synced
  bool get isComplete {
    // Find last non-empty marker
    int lastNonEmptyIndex = -1;
    for (int i = labels.length - 1; i >= 0; i--) {
      if (labels[i].isNotEmpty) {
        lastNonEmptyIndex = i;
        break;
      }
    }

    // If no non-empty markers, not complete
    if (lastNonEmptyIndex == -1) return false;

    // Complete if current index is at or past the last non-empty marker AND it's synced
    return currentIndex >= lastNonEmptyIndex &&
           syncedPositions.containsKey(lastNonEmptyIndex);
  }

  /// Get the synced position for a marker at the given index
  /// Returns null if marker is not synced
  int? getPositionForIndex(int index) => syncedPositions[index];

  /// Get the last (highest) synced position in milliseconds
  /// Returns 0 if no positions synced yet
  int getLastSyncedPosition() {
    if (syncedPositions.isEmpty) return 0;
    return syncedPositions.values.reduce((a, b) => a > b ? a : b);
  }

  /// Get the last synced position up to a given index (inclusive)
  /// Returns 0 if no positions synced yet or index < 0
  int getLastSyncedPositionUpTo(int index) {
    if (index < 0 || syncedPositions.isEmpty) return 0;
    int last = 0;
    for (final entry in syncedPositions.entries) {
      if (entry.key >= 0 && entry.key <= index && entry.value > last) {
        last = entry.value;
      }
    }
    return last;
  }

  /// Create a copy with updated fields
  MarkerSyncState copyWith({
    SyncStep? step,
    String? trackId,
    String? markerSetId,
    List<String>? labels,
    Map<int, int>? syncedPositions,
    int? currentIndex,
    bool? isDirty,
  }) {
    return MarkerSyncState(
      step: step ?? this.step,
      trackId: trackId ?? this.trackId,
      markerSetId: markerSetId ?? this.markerSetId,
      labels: labels ?? this.labels,
      syncedPositions: syncedPositions ?? this.syncedPositions,
      currentIndex: currentIndex ?? this.currentIndex,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [
        step,
        trackId,
        markerSetId,
        labels,
        syncedPositions,
        currentIndex,
        isDirty,
      ];
}
