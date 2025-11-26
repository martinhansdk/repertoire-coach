import '../../models/song_model.dart';
import 'database.dart' as db;

/// Local data source for song operations using Drift/SQLite
///
/// Provides CRUD operations for songs with local persistence.
/// All operations work offline. Sync tracking flags are managed
/// for future cloud synchronization.
class LocalSongDataSource {
  final db.AppDatabase _database;

  LocalSongDataSource(this._database);

  /// Get all active (non-deleted) songs for a specific concert as a stream
  ///
  /// Returns a reactive stream that updates whenever song data changes.
  /// Useful for UI that needs to stay in sync with database changes.
  Stream<List<SongModel>> watchSongsByConcert(String concertId) {
    return _database.watchSongsByConcert(concertId).map(
          (songs) => songs.map((s) => SongModel.fromDrift(s)).toList(),
        );
  }

  /// Get all active (non-deleted) songs for a specific concert as a future
  ///
  /// Returns a one-time snapshot of songs.
  /// Use this for non-reactive operations.
  Future<List<SongModel>> getSongsByConcert(String concertId) async {
    final songs = await _database.getSongsByConcert(concertId);
    return songs.map((s) => SongModel.fromDrift(s)).toList();
  }

  /// Get song by ID
  ///
  /// Returns null if song doesn't exist or is deleted.
  Future<SongModel?> getSongById(String id) async {
    final song = await _database.getSongById(id);
    return song != null ? SongModel.fromDrift(song) : null;
  }

  /// Insert or update a song
  ///
  /// If a song with the same ID exists, it will be updated.
  /// Otherwise, a new song is created.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertSong(
    SongModel song, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.songs).insertOnConflictUpdate(
          song.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert a song (fail if ID already exists)
  ///
  /// Throws an exception if a song with the same ID already exists.
  /// Use [upsertSong] if you want update-or-insert behavior.
  Future<void> insertSong(
    SongModel song, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.songs).insert(
          song.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Update an existing song
  ///
  /// Only updates if song exists. No-op if song doesn't exist.
  /// Returns true if update succeeded, false if song not found.
  Future<bool> updateSong(
    SongModel song, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.songs)
          ..where((s) => s.id.equals(song.id)))
        .write(song.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Soft delete a song
  ///
  /// Song is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  Future<void> deleteSong(String id) async {
    await _database.softDeleteSong(id);
  }

  /// Get all unsynced songs
  ///
  /// Used by sync service to find songs that need to be synced to cloud.
  Future<List<SongModel>> getUnsyncedSongs() async {
    final songs = await _database.getUnsyncedSongs();
    return songs.map((s) => SongModel.fromDrift(s)).toList();
  }

  /// Mark song as synced to cloud
  ///
  /// Called by sync service after successfully uploading to Supabase.
  Future<void> markAsSynced(String id) async {
    await _database.markSongAsSynced(id);
  }

  /// Clear all song data (for testing)
  ///
  /// Permanently deletes all songs. Use with caution!
  Future<void> clearAll() async {
    await _database.delete(_database.songs).go();
  }
}
