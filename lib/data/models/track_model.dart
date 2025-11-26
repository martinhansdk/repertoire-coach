import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../datasources/local/database.dart' as db;

/// Track data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class TrackModel extends Track {
  const TrackModel({
    required super.id,
    required super.songId,
    required super.name,
    required super.voicePart,
    super.filePath,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a TrackModel from a domain Track entity
  factory TrackModel.fromEntity(Track track) {
    return TrackModel(
      id: track.id,
      songId: track.songId,
      name: track.name,
      voicePart: track.voicePart,
      filePath: track.filePath,
      createdAt: track.createdAt,
      updatedAt: track.updatedAt,
    );
  }

  /// Convert to domain entity
  Track toEntity() {
    return Track(
      id: id,
      songId: songId,
      name: name,
      voicePart: voicePart,
      filePath: filePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a TrackModel from a Drift database record
  factory TrackModel.fromDrift(db.Track driftTrack) {
    return TrackModel(
      id: driftTrack.id,
      songId: driftTrack.songId,
      name: driftTrack.name,
      voicePart: driftTrack.voicePart,
      filePath: driftTrack.filePath,
      createdAt: driftTrack.createdAt,
      updatedAt: driftTrack.updatedAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.TracksCompanion toDriftCompanion({bool markForSync = true}) {
    return db.TracksCompanion(
      id: Value(id),
      songId: Value(songId),
      name: Value(name),
      voicePart: Value(voicePart),
      filePath: Value(filePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
