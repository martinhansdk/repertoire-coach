import 'package:drift/drift.dart';

import '../../models/marker_model.dart';
import '../../models/marker_set_model.dart';
import 'database.dart' as db;

/// Local data source for marker and marker set operations using Drift/SQLite
///
/// Provides CRUD operations for markers and marker sets with local persistence.
/// All operations work offline. Sync tracking flags are managed
/// for future cloud synchronization.
class LocalMarkerDataSource {
  final db.AppDatabase _database;

  LocalMarkerDataSource(this._database);

  // ==================== MarkerSet Operations ====================

  /// Get all active (non-deleted) marker sets for a specific track
  ///
  /// Returns marker sets that are either shared OR created by the specified user.
  /// For local-first mode, userId is optional and defaults to getting all sets.
  Future<List<MarkerSetModel>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) async {
    final query = _database.select(_database.markerSets)
      ..where((ms) => ms.trackId.equals(trackId))
      ..where((ms) => ms.deleted.equals(false));

    // If userId provided, filter to shared OR user's private sets
    if (userId != null) {
      query.where((ms) =>
          ms.isShared.equals(true) | ms.createdByUserId.equals(userId));
    }

    // Order by: shared first, then by name
    query.orderBy([
      (ms) => OrderingTerm(expression: ms.isShared, mode: OrderingMode.desc),
      (ms) => OrderingTerm.asc(ms.name),
    ]);

    final sets = await query.get();
    return sets.map((s) => MarkerSetModel.fromDrift(s)).toList();
  }

  /// Watch marker sets for a specific track (reactive stream)
  ///
  /// Returns a stream that updates whenever marker set data changes.
  Stream<List<MarkerSetModel>> watchMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) {
    final query = _database.select(_database.markerSets)
      ..where((ms) => ms.trackId.equals(trackId))
      ..where((ms) => ms.deleted.equals(false));

    if (userId != null) {
      query.where((ms) =>
          ms.isShared.equals(true) | ms.createdByUserId.equals(userId));
    }

    query.orderBy([
      (ms) => OrderingTerm(expression: ms.isShared, mode: OrderingMode.desc),
      (ms) => OrderingTerm.asc(ms.name),
    ]);

    return query.watch().map(
          (sets) => sets.map((s) => MarkerSetModel.fromDrift(s)).toList(),
        );
  }

  /// Get marker set by ID
  ///
  /// Returns null if marker set doesn't exist or is deleted.
  Future<MarkerSetModel?> getMarkerSetById(String id) async {
    final markerSet = await (_database.select(_database.markerSets)
          ..where((ms) => ms.id.equals(id))
          ..where((ms) => ms.deleted.equals(false)))
        .getSingleOrNull();

    return markerSet != null ? MarkerSetModel.fromDrift(markerSet) : null;
  }

  /// Insert or update a marker set
  ///
  /// If a marker set with the same ID exists, it will be updated.
  /// Otherwise, a new marker set is created.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.markerSets).insertOnConflictUpdate(
          markerSet.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert a marker set (fail if ID already exists)
  ///
  /// Throws an exception if a marker set with the same ID already exists.
  /// Use [upsertMarkerSet] if you want update-or-insert behavior.
  Future<void> insertMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.markerSets).insert(
          markerSet.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Update an existing marker set
  ///
  /// Only updates if marker set exists. No-op if marker set doesn't exist.
  /// Returns true if update succeeded, false if marker set not found.
  Future<bool> updateMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(markerSet.id)))
        .write(markerSet.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Soft delete a marker set
  ///
  /// Marker set is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  /// Also soft deletes all markers belonging to this set.
  Future<void> deleteMarkerSet(String id) async {
    // Soft delete the marker set
    await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(id)))
        .write(
      db.MarkerSetsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: const Value(false), // Mark for sync
      ),
    );

    // Also soft delete all markers in this set
    await (_database.update(_database.markers)
          ..where((m) => m.markerSetId.equals(id)))
        .write(
      const db.MarkersCompanion(
        deleted: Value(true),
        synced: Value(false), // Mark for sync
      ),
    );
  }

  /// Get all unsynced marker sets
  ///
  /// Used by sync service to find marker sets that need to be synced to cloud.
  Future<List<MarkerSetModel>> getUnsyncedMarkerSets() async {
    final sets = await (_database.select(_database.markerSets)
          ..where((ms) => ms.synced.equals(false)))
        .get();

    return sets.map((s) => MarkerSetModel.fromDrift(s)).toList();
  }

  /// Mark marker set as synced to cloud
  ///
  /// Called by sync service after successfully syncing to cloud.
  Future<void> markMarkerSetAsSynced(String id) async {
    await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(id)))
        .write(const db.MarkerSetsCompanion(synced: Value(true)));
  }

  // ==================== Marker Operations ====================

  /// Get all active (non-deleted) markers for a specific marker set
  ///
  /// Returns markers ordered by their display order.
  Future<List<MarkerModel>> getMarkersByMarkerSet(String markerSetId) async {
    final markers = await (_database.select(_database.markers)
          ..where((m) => m.markerSetId.equals(markerSetId))
          ..where((m) => m.deleted.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.displayOrder)]))
        .get();

    return markers.map((m) => MarkerModel.fromDrift(m)).toList();
  }

  /// Watch markers for a specific marker set (reactive stream)
  ///
  /// Returns a stream that updates whenever marker data changes.
  Stream<List<MarkerModel>> watchMarkersByMarkerSet(String markerSetId) {
    return (_database.select(_database.markers)
          ..where((m) => m.markerSetId.equals(markerSetId))
          ..where((m) => m.deleted.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.displayOrder)]))
        .watch()
        .map(
          (markers) => markers.map((m) => MarkerModel.fromDrift(m)).toList(),
        );
  }

  /// Get marker by ID
  ///
  /// Returns null if marker doesn't exist or is deleted.
  Future<MarkerModel?> getMarkerById(String id) async {
    final marker = await (_database.select(_database.markers)
          ..where((m) => m.id.equals(id))
          ..where((m) => m.deleted.equals(false)))
        .getSingleOrNull();

    return marker != null ? MarkerModel.fromDrift(marker) : null;
  }

  /// Insert or update a marker
  ///
  /// If a marker with the same ID exists, it will be updated.
  /// Otherwise, a new marker is created.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.markers).insertOnConflictUpdate(
          marker.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert a marker (fail if ID already exists)
  ///
  /// Throws an exception if a marker with the same ID already exists.
  /// Use [upsertMarker] if you want update-or-insert behavior.
  Future<void> insertMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.markers).insert(
          marker.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Update an existing marker
  ///
  /// Only updates if marker exists. No-op if marker doesn't exist.
  /// Returns true if update succeeded, false if marker not found.
  Future<bool> updateMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.markers)
          ..where((m) => m.id.equals(marker.id)))
        .write(marker.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Soft delete a marker
  ///
  /// Marker is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  Future<void> deleteMarker(String id) async {
    await (_database.update(_database.markers)..where((m) => m.id.equals(id)))
        .write(
      const db.MarkersCompanion(
        deleted: Value(true),
        synced: Value(false), // Mark for sync
      ),
    );
  }

  /// Get all unsynced markers
  ///
  /// Used by sync service to find markers that need to be synced to cloud.
  Future<List<MarkerModel>> getUnsyncedMarkers() async {
    final markers = await (_database.select(_database.markers)
          ..where((m) => m.synced.equals(false)))
        .get();

    return markers.map((m) => MarkerModel.fromDrift(m)).toList();
  }

  /// Mark marker as synced to cloud
  ///
  /// Called by sync service after successfully syncing to cloud.
  Future<void> markMarkerAsSynced(String id) async {
    await (_database.update(_database.markers)..where((m) => m.id.equals(id)))
        .write(const db.MarkersCompanion(synced: Value(true)));
  }
}
