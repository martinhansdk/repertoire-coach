import '../../domain/entities/marker.dart';

/// Marker data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class MarkerModel extends Marker {
  const MarkerModel({
    required super.id,
    required super.markerSetId,
    required super.label,
    required super.positionMs,
    required super.order,
    required super.createdAt,
  });

  /// Create a MarkerModel from a domain Marker entity
  factory MarkerModel.fromEntity(Marker marker) {
    return MarkerModel(
      id: marker.id,
      markerSetId: marker.markerSetId,
      label: marker.label,
      positionMs: marker.positionMs,
      order: marker.order,
      createdAt: marker.createdAt,
    );
  }

  /// Convert to domain entity
  Marker toEntity() {
    return Marker(
      id: id,
      markerSetId: markerSetId,
      label: label,
      positionMs: positionMs,
      order: order,
      createdAt: createdAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
