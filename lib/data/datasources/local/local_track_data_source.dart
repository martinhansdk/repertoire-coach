import '../../models/track_model.dart';
import 'database.dart' as db;

/// Local data source for track operations using Drift/SQLite
///
/// Provides CRUD operations for tracks with local persistence.
/// All operations work offline. Sync tracking flags are managed
/// for future cloud synchronization.
class LocalTrackDataSource {
  final db.AppDatabase _database;

  LocalTrackDataSource(this._database);

  /// Get all active (non-deleted) tracks for a specific song as a stream
  ///
  /// Returns a reactive stream that updates whenever track data changes.
  /// Useful for UI that needs to stay in sync with database changes.
  Stream<List<TrackModel>> watchTracksBySong(String songId) {
    return _database.watchTracksBySong(songId).map(
          (tracks) => tracks.map((t) => TrackModel.fromDrift(t)).toList(),
        );
  }

  /// Get all active (non-deleted) tracks for a specific song as a future
  ///
  /// Returns a one-time snapshot of tracks.
  /// Use this for non-reactive operations.
  Future<List<TrackModel>> getTracksBySong(String songId) async {
    final tracks = await _database.getTracksBySong(songId);
    return tracks.map((t) => TrackModel.fromDrift(t)).toList();
  }

  /// Get track by ID
  ///
  /// Returns null if track doesn't exist or is deleted.
  Future<TrackModel?> getTrackById(String id) async {
    final track = await _database.getTrackById(id);
    return track != null ? TrackModel.fromDrift(track) : null;
  }

  /// Insert or update a track
  ///
  /// If a track with the same ID exists, it will be updated.
  /// Otherwise, a new track is created.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertTrack(
    TrackModel track, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.tracks).insertOnConflictUpdate(
          track.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert a track (fail if ID already exists)
  ///
  /// Throws an exception if a track with the same ID already exists.
  /// Use [upsertTrack] if you want update-or-insert behavior.
  Future<void> insertTrack(
    TrackModel track, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.tracks).insert(
          track.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Update an existing track
  ///
  /// Only updates if track exists. No-op if track doesn't exist.
  /// Returns true if update succeeded, false if track not found.
  Future<bool> updateTrack(
    TrackModel track, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.tracks)
          ..where((t) => t.id.equals(track.id)))
        .write(track.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Soft delete a track
  ///
  /// Track is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  Future<void> deleteTrack(String id) async {
    await _database.softDeleteTrack(id);
  }

  /// Get all unsynced tracks
  ///
  /// Used by sync service to find tracks that need to be synced to cloud.
  Future<List<TrackModel>> getUnsyncedTracks() async {
    final tracks = await _database.getUnsyncedTracks();
    return tracks.map((t) => TrackModel.fromDrift(t)).toList();
  }

  /// Mark track as synced to cloud
  ///
  /// Called by sync service after successfully uploading to Supabase.
  Future<void> markAsSynced(String id) async {
    await _database.markTrackAsSynced(id);
  }

  /// Clear all track data (for testing)
  ///
  /// Permanently deletes all tracks. Use with caution!
  Future<void> clearAll() async {
    await _database.delete(_database.tracks).go();
  }
}
