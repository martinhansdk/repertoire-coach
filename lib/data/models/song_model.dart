import 'package:drift/drift.dart';

import '../../domain/entities/song.dart';
import '../datasources/local/database.dart' as db;

/// Song data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class SongModel extends Song {
  const SongModel({
    required super.id,
    required super.concertId,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a SongModel from a domain Song entity
  factory SongModel.fromEntity(Song song) {
    return SongModel(
      id: song.id,
      concertId: song.concertId,
      title: song.title,
      createdAt: song.createdAt,
      updatedAt: song.updatedAt,
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
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
