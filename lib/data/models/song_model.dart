import 'package:drift/drift.dart';

import '../../domain/entities/song.dart';
import '../datasources/local/database.dart' as db;

/// Song data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class SongModel extends Song {
  /// Whether this song has been soft-deleted (for sync tracking)
  final bool deleted;

  const SongModel({
    required super.id,
    required super.concertId,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
    this.deleted = false,
  });

  /// Create a SongModel from a domain Song entity
  factory SongModel.fromEntity(Song song) {
    return SongModel(
      id: song.id,
      concertId: song.concertId,
      title: song.title,
      createdAt: song.createdAt,
      updatedAt: song.updatedAt,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  /// Convert to domain entity
  Song toEntity() {
    return Song(
      id: id,
      concertId: concertId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a SongModel from a Drift database record
  factory SongModel.fromDrift(db.Song driftSong) {
    return SongModel(
      id: driftSong.id,
      concertId: driftSong.concertId,
      title: driftSong.title,
      createdAt: driftSong.createdAt,
      updatedAt: driftSong.updatedAt,
      deleted: driftSong.deleted,
    );
  }

  /// Convert to Drift companion for database writes
  db.SongsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.SongsCompanion(
      id: Value(id),
      concertId: Value(concertId),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  /// Create a SongModel from Supabase JSON
  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'],
      concertId: json['concert_id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'concert_id': concertId,
      'title': title,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }
}
