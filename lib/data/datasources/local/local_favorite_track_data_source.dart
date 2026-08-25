import 'package:drift/drift.dart';

import '../../../domain/entities/track.dart';
import '../../models/favorite_track_model.dart';
import 'database.dart' as db;

/// Local data source for favorite track operations using Drift/SQLite
///
/// Provides CRUD operations for user's favorite tracks.
/// All operations work offline. Favorites are per-user and sync to cloud.
class LocalFavoriteTrackDataSource {
  final db.AppDatabase _database;

  LocalFavoriteTrackDataSource(this._database);

  /// Watch all favorite tracks for a user
  ///
  /// Returns a stream that emits whenever favorites change.
  /// Results are sorted by added_at descending (most recent first).
  /// Excludes soft-deleted favorites.
  Stream<List<FavoriteTrackModel>> watchFavorites(String userId) {
    // Query with join to tracks table to get full Track data
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..where(_database.favoriteTracks.deleted.equals(false))
      ..orderBy([OrderingTerm.desc(_database.favoriteTracks.addedAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final favorite = row.readTable(_database.favoriteTracks);
        final trackRow = row.readTable(_database.tracks);

        // Create Track entity from Drift data
        final track = Track(
          id: trackRow.id,
          songId: trackRow.songId,
          name: trackRow.name,
          audioUrl: trackRow.audioUrl,
          storagePath: trackRow.storagePath,
          durationMs: trackRow.durationMs,
          filePath: trackRow.filePath,
          createdAt: trackRow.createdAt,
          updatedAt: trackRow.updatedAt,
        );

        return FavoriteTrackModel.fromDrift(
          driftFavorite: favorite,
          track: track,
        );
      }).toList();
    });
  }

  /// Get all favorite tracks for a user as a future
  ///
  /// Returns a one-time snapshot of favorites.
  /// Use this for non-reactive operations.
  /// Excludes soft-deleted favorites.
  Future<List<FavoriteTrackModel>> getFavorites(String userId) async {
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..where(_database.favoriteTracks.deleted.equals(false))
      ..orderBy([OrderingTerm.desc(_database.favoriteTracks.addedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      final favorite = row.readTable(_database.favoriteTracks);
      final trackRow = row.readTable(_database.tracks);

      // Create Track entity from Drift data
      final track = Track(
        id: trackRow.id,
        songId: trackRow.songId,
        name: trackRow.name,
        audioUrl: trackRow.audioUrl,
        storagePath: trackRow.storagePath,
        durationMs: trackRow.durationMs,
        filePath: trackRow.filePath,
        createdAt: trackRow.createdAt,
        updatedAt: trackRow.updatedAt,
      );

      return FavoriteTrackModel.fromDrift(
        driftFavorite: favorite,
        track: track,
      );
    }).toList();
  }

  /// Check if a track is favorited by a user
  ///
  /// Returns true if the track is in the user's favorites (and not deleted).
  Future<bool> isFavorite(String userId, String trackId) async {
    final count = await (_database.selectOnly(_database.favoriteTracks)
          ..addColumns([_database.favoriteTracks.userId])
          ..where(_database.favoriteTracks.userId.equals(userId))
          ..where(_database.favoriteTracks.trackId.equals(trackId))
          ..where(_database.favoriteTracks.deleted.equals(false)))
        .getSingleOrNull();

    return count != null;
  }

  /// Add a track to user's favorites
  ///
  /// Creates a favorite relationship. Idempotent - no error if already favorited.
  /// [markForSync] determines if this should sync to cloud (default: true).
  /// Requires userId to identify which user's favorites to modify.
  Future<void> addFavorite(
    String userId,
    FavoriteTrackModel favorite, {
    bool markForSync = true,
  }) async {
    if (!markForSync) {
      final existing = await (_database.select(_database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals(favorite.track.id)))
          .getSingleOrNull();
      // An unsynced local change (edit or soft-delete) that is not older than
      // the incoming row wins locally; it is resolved against remote on the
      // next push phase instead of being overwritten here.
      if (existing != null &&
          !existing.synced &&
          !existing.updatedAt.isBefore(favorite.updatedAt)) {
        return;
      }
    }

    final companion = favorite.toDriftCompanion(userId).copyWith(
          synced: Value(!markForSync),
          // User-initiated adds (markForSync=true) are live rows; sync pulls
          // (markForSync=false) must carry the remote deleted flag so
          // tombstones can be applied locally.
          deleted: markForSync ? const Value(false) : Value(favorite.deleted),
        );

    await _database.into(_database.favoriteTracks).insertOnConflictUpdate(
          companion,
        );
  }

  /// Remove a track from user's favorites (soft-delete)
  ///
  /// Marks the favorite as deleted and unsynced so the sync service
  /// can push the deletion to remote before hard-deleting.
  Future<void> removeFavorite(String userId, String trackId) async {
    await (_database.update(_database.favoriteTracks)
          ..where((f) => f.userId.equals(userId))
          ..where((f) => f.trackId.equals(trackId)))
        .write(db.FavoriteTracksCompanion(
      deleted: const Value(true),
      // The tombstone carries its deletion time so it participates in
      // newest-wins conflict resolution like any other change.
      updatedAt: Value(DateTime.now().toUtc()),
      synced: const Value(false),
    ));
  }

  /// Get count of favorite tracks for a user
  ///
  /// Used for startup logic to determine which tab to show.
  /// Excludes soft-deleted favorites.
  Future<int> getFavoriteCount(String userId) async {
    final result = await (_database.selectOnly(_database.favoriteTracks)
          ..addColumns([_database.favoriteTracks.userId.count()])
          ..where(_database.favoriteTracks.userId.equals(userId))
          ..where(_database.favoriteTracks.deleted.equals(false)))
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
  /// Excludes soft-deleted favorites (those are handled separately).
  Future<List<FavoriteTrackModel>> getUnsyncedFavorites(String userId) async {
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..where(_database.favoriteTracks.synced.equals(false))
      ..where(_database.favoriteTracks.deleted.equals(false));

    final rows = await query.get();
    return rows.map((row) {
      final favorite = row.readTable(_database.favoriteTracks);
      final trackRow = row.readTable(_database.tracks);

      // Create Track entity from Drift data
      final track = Track(
        id: trackRow.id,
        songId: trackRow.songId,
        name: trackRow.name,
        audioUrl: trackRow.audioUrl,
        storagePath: trackRow.storagePath,
        durationMs: trackRow.durationMs,
        filePath: trackRow.filePath,
        createdAt: trackRow.createdAt,
        updatedAt: trackRow.updatedAt,
      );

      return FavoriteTrackModel.fromDrift(
        driftFavorite: favorite,
        track: track,
      );
    }).toList();
  }

  /// Get all unsynced favorite records (raw, without track join)
  ///
  /// Used by sync service - returns both additions and soft-deletions.
  /// Returns raw Drift FavoriteTrack rows for lightweight access.
  Future<List<db.FavoriteTrack>> getUnsyncedFavoriteRecords(
      String userId) async {
    return await (_database.select(_database.favoriteTracks)
          ..where((f) => f.userId.equals(userId))
          ..where((f) => f.synced.equals(false)))
        .get();
  }

  /// Mark favorites as synced
  ///
  /// Called after successfully syncing to cloud.
  Future<void> markAsSynced(
      List<String> trackIds, String userId, DateTime expectedUpdatedAt) async {
    for (final trackId in trackIds) {
      // Conditional: no-op if the row was modified after the sync snapshot.
      await (_database.update(_database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals(trackId))
            ..where((f) => f.updatedAt.equals(expectedUpdatedAt)))
          .write(const db.FavoriteTracksCompanion(synced: Value(true)));
    }
  }

  /// Upsert a favorite record directly from sync data (no Track join needed)
  ///
  /// Used during sync pull phase to insert remote favorites locally.
  Future<void> upsertFavoriteRecord({
    required String userId,
    required String trackId,
    required String songId,
    required DateTime addedAt,
    bool markForSync = false,
  }) async {
    await _database.into(_database.favoriteTracks).insertOnConflictUpdate(
          db.FavoriteTracksCompanion(
            userId: Value(userId),
            trackId: Value(trackId),
            songId: Value(songId),
            addedAt: Value(addedAt),
            updatedAt: Value(addedAt),
            deleted: const Value(false),
            synced: Value(!markForSync),
          ),
        );
  }

  /// Hard-delete all synced favorites that are marked as deleted
  ///
  /// Called after sync has pushed the deletions to remote.
  Future<void> hardDeleteSyncedDeleted(String userId) async {
    await (_database.delete(_database.favoriteTracks)
          ..where((f) => f.userId.equals(userId))
          ..where((f) => f.deleted.equals(true))
          ..where((f) => f.synced.equals(true)))
        .go();
  }


  /// Get all synced favorites as a map (trackId -> FavoriteTrackModel)
  ///
  /// Used during pull phase to avoid re-pulling items already up-to-date.
  /// Map keys are track IDs (the syncId for favorites).
  Future<Map<String, FavoriteTrackModel>> getSyncedFavorites(
      String userId) async {
    final query = _database.select(_database.favoriteTracks).join([
      innerJoin(
        _database.tracks,
        _database.tracks.id.equalsExp(_database.favoriteTracks.trackId),
      ),
    ])
      ..where(_database.favoriteTracks.userId.equals(userId))
      ..where(_database.favoriteTracks.synced.equals(true));

    final rows = await query.get();
    final favorites = rows.map((row) {
      final favorite = row.readTable(_database.favoriteTracks);
      final trackRow = row.readTable(_database.tracks);

      final track = Track(
        id: trackRow.id,
        songId: trackRow.songId,
        name: trackRow.name,
        audioUrl: trackRow.audioUrl,
        storagePath: trackRow.storagePath,
        durationMs: trackRow.durationMs,
        filePath: trackRow.filePath,
        createdAt: trackRow.createdAt,
        updatedAt: trackRow.updatedAt,
      );

      return FavoriteTrackModel.fromDrift(
        driftFavorite: favorite,
        track: track,
      );
    }).toList();

    return Map.fromEntries(
      favorites.map((f) => MapEntry(f.track.id, f)),
    );
  }
}
