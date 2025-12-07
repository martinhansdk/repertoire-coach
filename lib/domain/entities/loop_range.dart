import 'package:equatable/equatable.dart';

/// Represents an A-B loop range for practice
///
/// Defines a loop region with start and end positions. Optionally
/// references markers that define the loop boundaries.
class LoopRange extends Equatable {
  /// Start position of the loop
  final Duration startPosition;

  /// End position of the loop
  final Duration endPosition;

  /// Optional ID of the marker at start position
  final String? startMarkerId;

  /// Optional ID of the marker at end position
  final String? endMarkerId;

  const LoopRange({
    required this.startPosition,
    required this.endPosition,
    this.startMarkerId,
    this.endMarkerId,
  }) : assert(
          endPosition > startPosition,
          'End position must be after start position',
        );

  /// Create a LoopRange from marker positions in milliseconds
  ///
  /// Converts millisecond positions to Duration objects.
  /// Optionally stores marker IDs for reference.
  factory LoopRange.fromMarkers({
    required int startPositionMs,
    required int endPositionMs,
    String? startMarkerId,
    String? endMarkerId,
  }) {
    return LoopRange(
      startPosition: Duration(milliseconds: startPositionMs),
      endPosition: Duration(milliseconds: endPositionMs),
      startMarkerId: startMarkerId,
      endMarkerId: endMarkerId,
    );
  }

  /// Check if a position is within this loop range
  ///
  /// Returns true if position >= startPosition and position < endPosition
  bool contains(Duration position) {
    return position >= startPosition && position < endPosition;
  }

  /// Get the duration of the loop
  Duration get duration => endPosition - startPosition;

  /// Check if the loop is valid (end > start)
  bool get isValid => endPosition > startPosition;

  @override
  List<Object?> get props => [
        startPosition,
        endPosition,
        startMarkerId,
        endMarkerId,
      ];

  @override
  String toString() {
    return 'LoopRange(start: $startPosition, end: $endPosition, duration: $duration)';
  }

  /// Create a copy with updated fields
  LoopRange copyWith({
    Duration? startPosition,
    Duration? endPosition,
    String? startMarkerId,
    String? endMarkerId,
  }) {
    return LoopRange(
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      startMarkerId: startMarkerId ?? this.startMarkerId,
      endMarkerId: endMarkerId ?? this.endMarkerId,
    );
  }
}
