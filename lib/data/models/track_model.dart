import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../datasources/local/database.dart' as db;

/// Track data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and JSON for Supabase integration.
class TrackModel extends Track {
  /// Whether this track has been soft-deleted (for sync tracking)
  final bool deleted;

  const TrackModel({
    required super.id,
    required super.songId,
    required super.name,
    super.audioUrl,
    super.storagePath,
    super.durationMs,
    super.filePath,
    required super.createdAt,
    required super.updatedAt,
    this.deleted = false,
  });

  /// Create a TrackModel from a domain Track entity
  factory TrackModel.fromEntity(Track track) {
    return TrackModel(
      id: track.id,
      songId: track.songId,
      name: track.name,
      audioUrl: track.audioUrl,
      storagePath: track.storagePath,
      durationMs: track.durationMs,
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
      audioUrl: audioUrl,
      storagePath: storagePath,
      durationMs: durationMs,
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
      audioUrl: driftTrack.audioUrl,
      storagePath: driftTrack.storagePath,
      durationMs: driftTrack.durationMs,
      filePath: driftTrack.filePath,
      createdAt: driftTrack.createdAt,
      updatedAt: driftTrack.updatedAt,
      deleted: driftTrack.deleted,
    );
  }

  /// Convert to Drift companion for database writes
  db.TracksCompanion toDriftCompanion({bool markForSync = true}) {
    return db.TracksCompanion(
      id: Value(id),
      songId: Value(songId),
      name: Value(name),
      audioUrl: Value(audioUrl),
      storagePath: Value(storagePath),
      durationMs: Value(durationMs),
      filePath: Value(filePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  /// Create a TrackModel from Supabase JSON
  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id'],
      songId: json['song_id'],
      name: json['name'],
      audioUrl: json['audio_url'],
      storagePath: json['storage_path'],
      durationMs: json['duration_ms'],
      filePath: json['file_path'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song_id': songId,
      'name': name,
      'audio_url': audioUrl,
      'storage_path': storagePath,
      'duration_ms': durationMs,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
