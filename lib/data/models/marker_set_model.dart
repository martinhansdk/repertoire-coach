import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/marker_set.dart';
import '../datasources/local/database.dart' as db;

/// MarkerSet data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class MarkerSetModel extends MarkerSet {
  /// Whether this marker set has been soft-deleted (for sync tracking)
  final bool deleted;
  final String markersJson;

  const MarkerSetModel({
    required super.id,
    required super.trackId,
    required super.name,
    required super.isShared,
    required super.isTimeSynced,
    required super.createdByUserId,
    required super.createdAt,
    required super.updatedAt,
    this.deleted = false,
    this.markersJson = '[]',
  });

  /// Create a MarkerSetModel from a domain MarkerSet entity
  factory MarkerSetModel.fromEntity(MarkerSet markerSet) {
    return MarkerSetModel(
      id: markerSet.id,
      trackId: markerSet.trackId,
      name: markerSet.name,
      isShared: markerSet.isShared,
      isTimeSynced: markerSet.isTimeSynced,
      createdByUserId: markerSet.createdByUserId,
      createdAt: markerSet.createdAt,
      updatedAt: markerSet.updatedAt,
      deleted: false,
      markersJson: '[]',
    );
  }

  /// Convert to domain entity
  MarkerSet toEntity() {
    return MarkerSet(
      id: id,
      trackId: trackId,
      name: name,
      isShared: isShared,
      isTimeSynced: isTimeSynced,
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
      isTimeSynced: driftMarkerSet.isTimeSynced,
      createdByUserId: driftMarkerSet.createdByUserId,
      createdAt: driftMarkerSet.createdAt,
      updatedAt: driftMarkerSet.updatedAt,
      deleted: driftMarkerSet.deleted,
      markersJson: driftMarkerSet.markersJson,
    );
  }

  /// Convert to Drift companion for database writes
  db.MarkerSetsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.MarkerSetsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      name: Value(name),
      isShared: Value(isShared),
      isTimeSynced: Value(isTimeSynced),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      markersJson: Value(markersJson),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  /// Create a MarkerSetModel from Supabase JSON
  factory MarkerSetModel.fromJson(Map<String, dynamic> json) {
    final rawMarkersJson = json['markers_json'];
    final markersJson = switch (rawMarkersJson) {
      String value => value,
      null => '[]',
      _ => jsonEncode(rawMarkersJson),
    };

    return MarkerSetModel(
      id: json['id'],
      trackId: json['track_id'],
      name: json['name'],
      isShared: json['is_shared'],
      isTimeSynced: json['is_time_synced'] ?? true,
      createdByUserId: json['created_by_user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      markersJson: markersJson,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    final parsedMarkersJson = jsonDecode(markersJson);
    return {
      'id': id,
      'track_id': trackId,
      'name': name,
      'is_shared': isShared,
      'is_time_synced': isTimeSynced,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'markers_json': parsedMarkersJson,
      'deleted': deleted,
    };
  }
}
