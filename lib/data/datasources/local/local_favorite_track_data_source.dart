import 'package:drift/drift.dart';

import '../../models/favorite_track_model.dart';
import 'database.dart' as db;

/// Local data source for favorite track operations using Drift/SQLite
///
/// Provides CRUD operations for user's favorite tracks.
/// All operations work offline. Favorites are per-user and sync to cloud.
class LocalFavoriteTrackDataSource {
  final db.AppDatabase _database;

  LocalFavoriteTrackDataSource(this._database);

  /// Watch all favorite tracks for a user with denormalized data
  ///
  /// Returns a stream that emits whenever favorites change.
  /// Results are sorted by added_at descending (most recent first).
  /// Includes denormalized data: track name, song title, choir name, audio URL, duration.
  Stream<List<FavoriteTrackModel>> watchFavorites(String userId) {
    // Custom query with joins to get denormalized data
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
      innerJoin(
        _database.songs,
        _database.songs.id.equalsExp(_database.favoriteTracks.songId),
      ),
      innerJoin(
        _database.concerts,
        _database.concerts.id.equalsExp(_database.songs.concertId),
      ),
      innerJoin(
        _database.choirs,
        _database.choirs.id.equalsExp(_database.concerts.choirId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(_database.favoriteTracks.addedAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final favorite = row.readTable(_database.favoriteTracks);
        final track = row.readTable(_database.tracks);
        final song = row.readTable(_database.songs);
        final choir = row.readTable(_database.choirs);

        return FavoriteTrackModel.fromDrift(
          driftFavorite: favorite,
          trackName: track.name,
          songTitle: song.title,
          choirName: choir.name,
          audioUrl: track.audioUrl,
          durationMs: track.durationMs,
        );
      }).toList();
    });
  }

  /// Get all favorite tracks for a user as a future
  ///
  /// Returns a one-time snapshot of favorites.
  /// Use this for non-reactive operations.
  Future<List<FavoriteTrackModel>> getFavorites(String userId) async {
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
      innerJoin(
        _database.songs,
        _database.songs.id.equalsExp(_database.favoriteTracks.songId),
      ),
      innerJoin(
        _database.concerts,
        _database.concerts.id.equalsExp(_database.songs.concertId),
      ),
      innerJoin(
        _database.choirs,
        _database.choirs.id.equalsExp(_database.concerts.choirId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..orderBy([OrderingTerm.desc(_database.favoriteTracks.addedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      final favorite = row.readTable(_database.favoriteTracks);
      final track = row.readTable(_database.tracks);
      final song = row.readTable(_database.songs);
      final choir = row.readTable(_database.choirs);

      return FavoriteTrackModel.fromDrift(
        driftFavorite: favorite,
        trackName: track.name,
        songTitle: song.title,
        choirName: choir.name,
        audioUrl: track.audioUrl,
        durationMs: track.durationMs,
      );
    }).toList();
  }

  /// Check if a track is favorited by a user
  ///
  /// Returns true if the track is in the user's favorites, false otherwise.
  Future<bool> isFavorite(String userId, String trackId) async {
    final count = await (_database.selectOnly(_database.favoriteTracks)
          ..addColumns([_database.favoriteTracks.userId])
          ..where(_database.favoriteTracks.userId.equals(userId))
          ..where(_database.favoriteTracks.trackId.equals(trackId)))
        .getSingleOrNull();

    return count != null;
  }

  /// Add a track to user's favorites
  ///
  /// Creates a favorite relationship. Idempotent - no error if already favorited.
  /// [markForSync] determines if this should sync to cloud (default: true).
  Future<void> addFavorite(
    FavoriteTrackModel favorite, {
    bool markForSync = true,
  }) async {
    final companion = favorite.toDriftCompanion().copyWith(
          synced: Value(!markForSync), // If markForSync=true, synced=false
        );

    await _database.into(_database.favoriteTracks).insertOnConflictUpdate(
          companion,
        );
  }

  /// Remove a track from user's favorites
  ///
  /// Deletes the favorite relationship. Idempotent - no error if not favorited.
  Future<void> removeFavorite(String userId, String trackId) async {
    await (_database.delete(_database.favoriteTracks)
          ..where((f) => f.userId.equals(userId))
          ..where((f) => f.trackId.equals(trackId)))
        .go();
  }

  /// Get count of favorite tracks for a user
  ///
  /// Used for startup logic to determine which tab to show.
  Future<int> getFavoriteCount(String userId) async {
    final result = await (_database.selectOnly(_database.favoriteTracks)
          ..addColumns([_database.favoriteTracks.userId.count()])
          ..where(_database.favoriteTracks.userId.equals(userId)))
        .getSingle();

    return result.read(_database.favoriteTracks.userId.count()) ?? 0;
  }

  /// Clear all favorites for a user (for testing)
  Future<void> clearAllForUser(String userId) async {
    await (_database.delete(_database.favoriteTracks)
          ..where((f) => f.userId.equals(userId)))
        .go();
  }

  /// Get all un-synced favorites (for sync to cloud)
  ///
  /// Returns favorites that have been added/modified locally but not yet synced.
  Future<List<FavoriteTrackModel>> getUnsyncedFavorites(String userId) async {
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
      innerJoin(
        _database.songs,
        _database.songs.id.equalsExp(_database.favoriteTracks.songId),
      ),
      innerJoin(
        _database.concerts,
        _database.concerts.id.equalsExp(_database.songs.concertId),
      ),
      innerJoin(
        _database.choirs,
        _database.choirs.id.equalsExp(_database.concerts.choirId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..where(_database.favoriteTracks.synced.equals(false));

    final rows = await query.get();
    return rows.map((row) {
      final favorite = row.readTable(_database.favoriteTracks);
      final track = row.readTable(_database.tracks);
      final song = row.readTable(_database.songs);
      final choir = row.readTable(_database.choirs);

      return FavoriteTrackModel.fromDrift(
        driftFavorite: favorite,
        trackName: track.name,
        songTitle: song.title,
        choirName: choir.name,
        audioUrl: track.audioUrl,
        durationMs: track.durationMs,
      );
    }).toList();
  }

  /// Mark favorites as synced
  ///
  /// Called after successfully syncing to cloud.
  Future<void> markAsSynced(List<String> trackIds, String userId) async {
    for (final trackId in trackIds) {
      await (_database.update(_database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals(trackId)))
          .write(const db.FavoriteTracksCompanion(synced: Value(true)));
    }
  }
}
