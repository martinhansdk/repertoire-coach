import 'package:drift/drift.dart';

import '../../domain/entities/favorite_track.dart';
import '../../domain/entities/track.dart';
import '../datasources/local/database.dart' as db;

/// Favorite track data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and JSON for Supabase integration.
class FavoriteTrackModel extends FavoriteTrack {
  /// Whether this favorite has been soft-deleted (for sync tracking)
  final bool deleted;

  const FavoriteTrackModel({
    required super.addedAt,
    required super.updatedAt,
    required super.track,
    this.deleted = false,
  });

  /// Create a FavoriteTrackModel from a domain FavoriteTrack entity
  factory FavoriteTrackModel.fromEntity(FavoriteTrack favorite) {
    return FavoriteTrackModel(
      addedAt: favorite.addedAt,
      updatedAt: favorite.updatedAt,
      track: favorite.track,
    );
  }

  /// Convert to domain entity
  FavoriteTrack toEntity() {
    return FavoriteTrack(
      addedAt: addedAt,
      updatedAt: updatedAt,
      track: track,
    );
  }

  /// Create a FavoriteTrackModel from a Drift database record
  ///
  /// Note: Drift stores the favorite relationship (user_id, track_id, song_id, added_at).
  /// The full Track object must be provided from joined queries.
  factory FavoriteTrackModel.fromDrift({
    required db.FavoriteTrack driftFavorite,
    required Track track,
  }) {
    return FavoriteTrackModel(
      addedAt: driftFavorite.addedAt,
      updatedAt: driftFavorite.updatedAt,
      track: track,
      deleted: driftFavorite.deleted,
    );
  }

  /// Convert to Drift companion for database writes
  ///
  /// Requires userId to be passed explicitly (not stored in entity).
  /// Writes the core favorite relationship to the database.
  db.FavoriteTracksCompanion toDriftCompanion(String userId) {
    return db.FavoriteTracksCompanion(
      userId: Value(userId),
      trackId: Value(track.id),
      songId: Value(track.songId),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  /// Create a FavoriteTrackModel from Supabase JSON
  ///
  /// Expects JSON from query with join to tracks table.
  /// The 'tracks' field should contain the full track data.
  factory FavoriteTrackModel.fromJson(Map<String, dynamic> json) {
    // Extract track data and create Track object
    final trackData = json['tracks'] as Map<String, dynamic>;
    final createdAt = DateTime.parse(trackData['created_at'] as String);

    final track = Track(
      id: json['track_id'] as String,
      songId: json['song_id'] as String,
      name: trackData['name'] as String,
      audioUrl: trackData['audio_url'] as String?,
      storagePath: trackData['storage_path'] as String?,
      durationMs: trackData['duration_ms'] as int?,
      filePath: null, // Not stored in Supabase
      createdAt: createdAt,
      updatedAt: createdAt, // Supabase tracks table doesn't have updated_at, use created_at
    );

    return FavoriteTrackModel(
      addedAt: DateTime.parse(json['added_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      track: track,
    );
  }

  /// Convert to JSON for Supabase writes
  ///
  /// Requires userId to be passed explicitly (not stored in entity).
  /// Returns the data needed for INSERT/UPDATE operations.
  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'track_id': track.id,
      'song_id': track.songId,
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
