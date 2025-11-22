import 'package:equatable/equatable.dart';

/// Represents a named collection of markers for a track
/// Can be shared with choir members or private to a user
class MarkerSet extends Equatable {
  final String id;
  final String trackId;
  final String name;
  final bool isShared; // true = shared with choir, false = private to user
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MarkerSet({
    required this.id,
    required this.trackId,
    required this.name,
    required this.isShared,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        trackId,
        name,
        isShared,
        createdByUserId,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'MarkerSet(id: $id, trackId: $trackId, name: $name, isShared: $isShared)';
  }
}
