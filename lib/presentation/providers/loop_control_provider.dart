import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/loop_range.dart';
import '../../domain/entities/marker.dart';
import 'audio_player_provider.dart';

/// Helper class for controlling A-B loop functionality
///
/// Provides convenient methods for setting loop ranges from markers
/// or custom positions, and clearing loops.
class LoopControls {
  final Ref _ref;

  LoopControls(this._ref);

  /// Set a loop range from a start marker to an end marker
  ///
  /// [startMarker] - The marker defining the loop start position
  /// [endMarker] - The marker defining the loop end position
  ///
  /// Throws [ArgumentError] if endMarker position is not after startMarker position
  Future<void> setLoopFromMarkers(Marker startMarker, Marker endMarker) async {
    final startPosition = Duration(milliseconds: startMarker.positionMs);
    final endPosition = Duration(milliseconds: endMarker.positionMs);

    if (endPosition <= startPosition) {
      throw ArgumentError(
        'End marker must be after start marker. '
        'Start: ${startMarker.positionMs}ms, End: ${endMarker.positionMs}ms',
      );
    }

    final loopRange = LoopRange(
      startPosition: startPosition,
      endPosition: endPosition,
      startMarkerId: startMarker.id,
      endMarkerId: endMarker.id,
    );

    final repository = _ref.read(audioPlayerRepositoryProvider);
    await repository.setLoopRange(loopRange);
  }

  /// Set a loop range from a marker to a custom position
  ///
  /// [marker] - The marker defining one end of the loop
  /// [customPosition] - The custom position for the other end
  /// [markerIsStart] - If true, marker is the start; if false, marker is the end
  ///
  /// Throws [ArgumentError] if positions create an invalid range
  Future<void> setLoopFromMarkerToPosition({
    required Marker marker,
    required Duration customPosition,
    required bool markerIsStart,
  }) async {
    final markerPosition = Duration(milliseconds: marker.positionMs);

    final Duration startPosition;
    final Duration endPosition;
    final String? startMarkerId;
    final String? endMarkerId;

    if (markerIsStart) {
      startPosition = markerPosition;
      endPosition = customPosition;
      startMarkerId = marker.id;
      endMarkerId = null;

      if (endPosition <= startPosition) {
        throw ArgumentError(
          'Custom end position must be after marker start position. '
          'Start: ${marker.positionMs}ms, End: ${customPosition.inMilliseconds}ms',
        );
      }
    } else {
      startPosition = customPosition;
      endPosition = markerPosition;
      startMarkerId = null;
      endMarkerId = marker.id;

      if (endPosition <= startPosition) {
        throw ArgumentError(
          'Marker end position must be after custom start position. '
          'Start: ${customPosition.inMilliseconds}ms, End: ${marker.positionMs}ms',
        );
      }
    }

    final loopRange = LoopRange(
      startPosition: startPosition,
      endPosition: endPosition,
      startMarkerId: startMarkerId,
      endMarkerId: endMarkerId,
    );

    final repository = _ref.read(audioPlayerRepositoryProvider);
    await repository.setLoopRange(loopRange);
  }

  /// Set a custom loop range between two arbitrary positions
  ///
  /// [startPosition] - The start position of the loop
  /// [endPosition] - The end position of the loop
  ///
  /// Throws [ArgumentError] if endPosition is not after startPosition
  Future<void> setCustomLoop({
    required Duration startPosition,
    required Duration endPosition,
  }) async {
    if (endPosition <= startPosition) {
      throw ArgumentError(
        'End position must be after start position. '
        'Start: ${startPosition.inMilliseconds}ms, End: ${endPosition.inMilliseconds}ms',
      );
    }

    final loopRange = LoopRange(
      startPosition: startPosition,
      endPosition: endPosition,
    );

    final repository = _ref.read(audioPlayerRepositoryProvider);
    await repository.setLoopRange(loopRange);
  }

  /// Clear the current loop range
  ///
  /// Stops A-B loop playback and returns to normal playback mode
  Future<void> clearLoop() async {
    final repository = _ref.read(audioPlayerRepositoryProvider);
    await repository.setLoopRange(null);
  }

  /// Get the current loop range (if any)
  ///
  /// Returns null if no loop is currently active
  LoopRange? get currentLoopRange {
    final repository = _ref.read(audioPlayerRepositoryProvider);
    return repository.currentLoopRange;
  }

  /// Check if a loop is currently active
  bool get isLooping {
    final repository = _ref.read(audioPlayerRepositoryProvider);
    return repository.isRangeLooping;
  }
}

/// Provider for loop controls
///
/// Use this to manage A-B loop functionality from UI widgets.
///
/// Examples:
/// ```dart
/// // Set loop from two markers
/// await ref.read(loopControlsProvider).setLoopFromMarkers(startMarker, endMarker);
///
/// // Set loop from marker to custom position
/// await ref.read(loopControlsProvider).setLoopFromMarkerToPosition(
///   marker: myMarker,
///   customPosition: Duration(seconds: 30),
///   markerIsStart: true,
/// );
///
/// // Set custom loop
/// await ref.read(loopControlsProvider).setCustomLoop(
///   startPosition: Duration(seconds: 10),
///   endPosition: Duration(seconds: 20),
/// );
///
/// // Clear loop
/// await ref.read(loopControlsProvider).clearLoop();
///
/// // Check if looping
/// final isLooping = ref.read(loopControlsProvider).isLooping;
/// ```
final loopControlsProvider = Provider<LoopControls>((ref) {
  return LoopControls(ref);
});
