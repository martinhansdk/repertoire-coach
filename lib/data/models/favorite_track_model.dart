import 'package:drift/drift.dart';

import '../../domain/entities/favorite_track.dart';
import '../datasources/local/database.dart' as db;

/// Favorite track data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and JSON for Supabase integration.
class FavoriteTrackModel extends FavoriteTrack {
  const FavoriteTrackModel({
    required super.userId,
    required super.trackId,
    required super.songId,
    required super.addedAt,
    required super.trackName,
    required super.songTitle,
    required super.choirName,
    super.audioUrl,
    super.durationMs,
  });

  /// Create a FavoriteTrackModel from a domain FavoriteTrack entity
  factory FavoriteTrackModel.fromEntity(FavoriteTrack favorite) {
    return FavoriteTrackModel(
      userId: favorite.userId,
      trackId: favorite.trackId,
      songId: favorite.songId,
      addedAt: favorite.addedAt,
      trackName: favorite.trackName,
      songTitle: favorite.songTitle,
      choirName: favorite.choirName,
      audioUrl: favorite.audioUrl,
      durationMs: favorite.durationMs,
    );
  }

  /// Convert to domain entity
  FavoriteTrack toEntity() {
    return FavoriteTrack(
      userId: userId,
      trackId: trackId,
      songId: songId,
      addedAt: addedAt,
      trackName: trackName,
      songTitle: songTitle,
      choirName: choirName,
      audioUrl: audioUrl,
      durationMs: durationMs,
    );
  }

  /// Create a FavoriteTrackModel from a Drift database record
  ///
  /// Note: Drift only stores the core favorite relationship (user_id, track_id, song_id, added_at).
  /// Denormalized fields (track_name, song_title, choir_name, audio_url, duration_ms)
  /// must be provided separately from joined queries.
  factory FavoriteTrackModel.fromDrift({
    required db.FavoriteTrack driftFavorite,
    required String trackName,
    required String songTitle,
    required String choirName,
    String? audioUrl,
    int? durationMs,
  }) {
    return FavoriteTrackModel(
      userId: driftFavorite.userId,
      trackId: driftFavorite.trackId,
      songId: driftFavorite.songId,
      addedAt: driftFavorite.addedAt,
      trackName: trackName,
      songTitle: songTitle,
      choirName: choirName,
      audioUrl: audioUrl,
      durationMs: durationMs,
    );
  }

  /// Convert to Drift companion for database writes
  ///
  /// Only writes the core favorite relationship.
  /// Denormalized fields are not stored in the favorite_tracks table.
  db.FavoriteTracksCompanion toDriftCompanion() {
    return db.FavoriteTracksCompanion(
      userId: Value(userId),
      trackId: Value(trackId),
      songId: Value(songId),
      addedAt: Value(addedAt),
    );
  }

  /// Create a FavoriteTrackModel from Supabase JSON
  ///
  /// Expects JSON from the denormalized query with joins to tracks, songs, concerts, and choirs.
  factory FavoriteTrackModel.fromJson(Map<String, dynamic> json) {
    return FavoriteTrackModel(
      userId: json['user_id'] as String,
      trackId: json['track_id'] as String,
      songId: json['song_id'] as String,
      addedAt: DateTime.parse(json['added_at'] as String),
      trackName: json['track_name'] as String,
      songTitle: json['song_title'] as String,
      choirName: json['choir_name'] as String,
      audioUrl: json['audio_url'] as String?,
      durationMs: json['duration_ms'] as int?,
    );
  }

  /// Convert to JSON for Supabase
  ///
  /// Only includes the core favorite relationship fields.
  /// The denormalized fields are computed by Supabase queries with joins.
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'track_id': trackId,
      'song_id': songId,
      'added_at': addedAt.toIso8601String(),
    };
  }
}
