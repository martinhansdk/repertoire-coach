import 'package:drift/drift.dart';

import '../../domain/entities/marker_set.dart';
import '../datasources/local/database.dart' as db;

/// MarkerSet data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
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

  /// Create a MarkerSetModel from a Drift database record
  factory MarkerSetModel.fromDrift(db.MarkerSet driftMarkerSet) {
    return MarkerSetModel(
      id: driftMarkerSet.id,
      trackId: driftMarkerSet.trackId,
      name: driftMarkerSet.name,
      isShared: driftMarkerSet.isShared,
      createdByUserId: driftMarkerSet.createdByUserId,
      createdAt: driftMarkerSet.createdAt,
      updatedAt: driftMarkerSet.updatedAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.MarkerSetsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.MarkerSetsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      name: Value(name),
      isShared: Value(isShared),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
