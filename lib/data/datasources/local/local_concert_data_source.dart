import '../../models/concert_model.dart';
import 'database.dart' as db;

/// Local data source for concert operations using Drift/SQLite
///
/// Provides CRUD operations for concerts with local persistence.
/// All operations work offline. Sync tracking flags are managed
/// for future cloud synchronization.
class LocalConcertDataSource {
  final db.AppDatabase _database;

  LocalConcertDataSource(this._database);

  /// Get all active (non-deleted) concerts as a stream
  ///
  /// Returns a reactive stream that updates whenever concert data changes.
  /// Useful for UI that needs to stay in sync with database changes.
  Stream<List<ConcertModel>> watchConcerts() {
    return _database.watchAllConcerts().map((concerts) =>
        concerts.map((c) => ConcertModel.fromDrift(c)).toList());
  }

  /// Get all active (non-deleted) concerts as a future
  ///
  /// Returns a one-time snapshot of concerts.
  /// Use this for non-reactive operations.
  Future<List<ConcertModel>> getConcerts() async {
    final concerts = await _database.getAllConcerts();
    return concerts.map((c) => ConcertModel.fromDrift(c)).toList();
  }

  /// Get concert by ID
  ///
  /// Returns null if concert doesn't exist or is deleted.
  Future<ConcertModel?> getConcertById(String id) async {
    final concert = await _database.getConcertById(id);
    return concert != null ? ConcertModel.fromDrift(concert) : null;
  }

  /// Insert or update a concert
  ///
  /// If a concert with the same ID exists, it will be updated.
  /// Otherwise, a new concert is created.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertConcert(
    ConcertModel concert, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.concerts).insertOnConflictUpdate(
          concert.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert a concert (fail if ID already exists)
  ///
  /// Throws an exception if a concert with the same ID already exists.
  /// Use [upsertConcert] if you want update-or-insert behavior.
  Future<void> insertConcert(
    ConcertModel concert, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.concerts).insert(
          concert.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Update an existing concert
  ///
  /// Only updates if concert exists. No-op if concert doesn't exist.
  /// Returns true if update succeeded, false if concert not found.
  Future<bool> updateConcert(
    ConcertModel concert, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.concerts)
          ..where((c) => c.id.equals(concert.id)))
        .write(concert.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Soft delete a concert
  ///
  /// Concert is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  Future<void> deleteConcert(String id) async {
    await _database.softDeleteConcert(id);
  }

  /// Get all unsynced concerts
  ///
  /// Used by sync service to find concerts that need to be synced to cloud.
  Future<List<ConcertModel>> getUnsyncedConcerts() async {
    final concerts = await _database.getUnsyncedConcerts();
    return concerts.map((c) => ConcertModel.fromDrift(c)).toList();
  }

  /// Mark concert as synced to cloud
  ///
  /// Called by sync service after successfully uploading to Supabase.
  Future<void> markAsSynced(String id) async {
    await _database.markConcertAsSynced(id);
  }

  /// Clear all concert data (for testing)
  ///
  /// Permanently deletes all concerts. Use with caution!
  Future<void> clearAll() async {
    await _database.delete(_database.concerts).go();
  }
}
