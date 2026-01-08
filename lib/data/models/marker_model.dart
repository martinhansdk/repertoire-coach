import 'package:drift/drift.dart';

import '../../domain/entities/marker.dart';
import '../datasources/local/database.dart' as db;

/// Marker data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
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

  /// Create a MarkerModel from a Drift database record
  factory MarkerModel.fromDrift(db.Marker driftMarker) {
    return MarkerModel(
      id: driftMarker.id,
      markerSetId: driftMarker.markerSetId,
      label: driftMarker.label,
      positionMs: driftMarker.positionMs,
      order: driftMarker.displayOrder, // Map displayOrder to order
      createdAt: driftMarker.createdAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.MarkersCompanion toDriftCompanion({bool markForSync = true}) {
    return db.MarkersCompanion(
      id: Value(id),
      markerSetId: Value(markerSetId),
      label: Value(label),
      positionMs: Value(positionMs),
      displayOrder: Value(order), // Map order to displayOrder
      createdAt: Value(createdAt),
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  /// Create a MarkerModel from Supabase JSON
  factory MarkerModel.fromJson(Map<String, dynamic> json) {
    return MarkerModel(
      id: json['id'],
      markerSetId: json['marker_set_id'],
      label: json['label'],
      positionMs: json['position_ms'],
      order: json['display_order'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marker_set_id': markerSetId,
      'label': label,
      'position_ms': positionMs,
      'display_order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
