import '../../domain/entities/marker_set.dart';

/// MarkerSet data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class MarkerSetModel extends MarkerSet {
  const MarkerSetModel({
    required super.id,
    required super.trackId,
    required super.name,
    required super.isShared,
    required super.createdByUserId,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a MarkerSetModel from a domain MarkerSet entity
  factory MarkerSetModel.fromEntity(MarkerSet markerSet) {
    return MarkerSetModel(
      id: markerSet.id,
      trackId: markerSet.trackId,
      name: markerSet.name,
      isShared: markerSet.isShared,
      createdByUserId: markerSet.createdByUserId,
      createdAt: markerSet.createdAt,
      updatedAt: markerSet.updatedAt,
    );
  }

  /// Convert to domain entity
  MarkerSet toEntity() {
    return MarkerSet(
      id: id,
      trackId: trackId,
      name: name,
      isShared: isShared,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
