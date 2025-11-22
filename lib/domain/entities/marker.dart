import 'package:equatable/equatable.dart';

/// Represents a position marker within a track
/// Examples: section labels, bar numbers, rehearsal marks
class Marker extends Equatable {
  final String id;
  final String markerSetId;
  final String label;
  final int positionMs; // Position in track in milliseconds
  final int order; // Order within the marker set for display
  final DateTime createdAt;

  const Marker({
    required this.id,
    required this.markerSetId,
    required this.label,
    required this.positionMs,
    required this.order,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        markerSetId,
        label,
        positionMs,
        order,
        createdAt,
      ];

  @override
  String toString() {
    return 'Marker(id: $id, label: $label, positionMs: ${positionMs}ms, order: $order)';
  }
}
