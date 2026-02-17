import 'package:drift/drift.dart';

import '../../models/choir_member_model.dart';
import '../../models/choir_model.dart';
import 'database.dart' as db;

/// Local data source for choir and membership operations using Drift/SQLite
///
/// Provides CRUD operations for choirs and choir members with local persistence.
/// All operations work offline. Sync tracking flags are managed
/// for future cloud synchronization.
class LocalChoirDataSource {
  final db.AppDatabase _database;

  LocalChoirDataSource(this._database);

  // ============================================================================
  // CHOIR OPERATIONS
  // ============================================================================

  /// Get all active (non-deleted) choirs for a user as a stream
  ///
  /// Returns a reactive stream that updates whenever choir data changes.
  /// Only returns choirs where the user is a member.
  Stream<List<ChoirModel>> watchChoirs(String userId) {
    // Query choirs by joining with choir_members where user is a member
    final query = _database.select(_database.choirs).join([
      innerJoin(
        _database.choirMembers,
        _database.choirMembers.choirId.equalsExp(_database.choirs.id),
      ),
    ])
      ..where(_database.choirs.deleted.equals(false))
      ..where(_database.choirMembers.userId.equals(userId));

    return query.watch().map((rows) {
      return rows.map((row) {
        final choir = row.readTable(_database.choirs);
        return ChoirModel.fromDrift(choir);
      }).toList();
    });
  }

  /// Get all active (non-deleted) choirs for a user as a future
  ///
  /// Returns a one-time snapshot of choirs.
  /// Only returns choirs where the user is a member.
  Future<List<ChoirModel>> getChoirs(String userId) async {
    final query = _database.select(_database.choirs).join([
      innerJoin(
        _database.choirMembers,
        _database.choirMembers.choirId.equalsExp(_database.choirs.id),
      ),
    ])
      ..where(_database.choirs.deleted.equals(false))
      ..where(_database.choirMembers.userId.equals(userId));

    final rows = await query.get();
    return rows.map((row) {
      final choir = row.readTable(_database.choirs);
      return ChoirModel.fromDrift(choir);
    }).toList();
  }

  /// Get choir by ID
  ///
  /// Returns null if choir doesn't exist or is deleted.
  Future<ChoirModel?> getChoirById(String id) async {
    final choir = await (_database.select(_database.choirs)
          ..where((c) => c.id.equals(id))
          ..where((c) => c.deleted.equals(false)))
        .getSingleOrNull();

    return choir != null ? ChoirModel.fromDrift(choir) : null;
  }

  /// Create a new choir
  ///
  /// Creates the choir and automatically adds the creator as a member.
  /// This should be used when a user creates a new choir.
  Future<void> createChoir(
    ChoirModel choir,
    String creatorUserId, {
    bool markForSync = true,
  }) async {
    await _database.transaction(() async {
      // Insert the choir
      await _database.into(_database.choirs).insert(
            choir.toDriftCompanion(markForSync: markForSync),
          );

      // Add creator as a member
      final member = ChoirMemberModel(
        choirId: choir.id,
        userId: creatorUserId,
        joinedAt: DateTime.now().toUtc(),
      );
      await _database.into(_database.choirMembers).insert(
            member.toDriftCompanion(markForSync: markForSync),
          );
    });
  }

  /// Update an existing choir
  ///
  /// Only updates if choir exists. No-op if choir doesn't exist.
  /// Returns true if update succeeded, false if choir not found.
  Future<bool> updateChoir(
    ChoirModel choir, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.choirs)
          ..where((c) => c.id.equals(choir.id)))
        .write(choir.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  /// Insert or update a choir
  ///
  /// If a choir with the same ID exists, it will be updated.
  /// Otherwise, a new choir is created.
  /// Note: This does NOT automatically add the creator as a member.
  /// Use this for sync operations where choir and membership are separate.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertChoir(
    ChoirModel choir, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.choirs).insertOnConflictUpdate(
          choir.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Insert or update a choir member
  ///
  /// If the member already exists, it will be updated.
  /// Otherwise, a new member is created.
  /// Use this for sync operations.
  /// [markForSync] determines if this change should be synced to cloud (default: true)
  Future<void> upsertMember(
    ChoirMemberModel member, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.choirMembers).insertOnConflictUpdate(
          member.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Soft delete a choir
  ///
  /// Choir is marked as deleted but not removed from database.
  /// This allows the deletion to sync to cloud before being purged.
  /// Note: Choir members are not deleted, only the choir itself.
  Future<void> deleteChoir(String id) async {
    await (_database.update(_database.choirs)..where((c) => c.id.equals(id)))
        .write(
      db.ChoirsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: const Value(false), // Mark for sync
      ),
    );
  }

  // ============================================================================
  // CHOIR MEMBERSHIP OPERATIONS
  // ============================================================================

  /// Add a member to a choir
  ///
  /// Throws an exception if the user is already a member.
  Future<void> addMember(
    String choirId,
    String userId, {
    bool markForSync = true,
  }) async {
    final member = ChoirMemberModel(
      choirId: choirId,
      userId: userId,
      joinedAt: DateTime.now().toUtc(),
    );

    await _database.into(_database.choirMembers).insert(
          member.toDriftCompanion(markForSync: markForSync),
        );
  }

  /// Remove a member from a choir
  ///
  /// Returns true if member was removed, false if member wasn't found.
  Future<bool> removeMember(String choirId, String userId) async {
    final rowsAffected = await (_database.delete(_database.choirMembers)
          ..where((m) => m.choirId.equals(choirId))
          ..where((m) => m.userId.equals(userId)))
        .go();

    return rowsAffected > 0;
  }

  /// Get all member user IDs for a choir
  ///
  /// Returns list of user IDs who are members of the choir.
  Future<List<String>> getChoirMembers(String choirId) async {
    final members = await (_database.select(_database.choirMembers)
          ..where((m) => m.choirId.equals(choirId)))
        .get();

    return members.map((m) => m.userId).toList();
  }

  /// Check if a user is a member of a choir
  Future<bool> isMember(String choirId, String userId) async {
    final member = await (_database.select(_database.choirMembers)
          ..where((m) => m.choirId.equals(choirId))
          ..where((m) => m.userId.equals(userId)))
        .getSingleOrNull();

    return member != null;
  }

  /// Check if a user is the owner of a choir
  Future<bool> isOwner(String choirId, String userId) async {
    final choir = await getChoirById(choirId);
    return choir?.ownerId == userId;
  }

  /// Get the number of members in a choir
  Future<int> getMemberCount(String choirId) async {
    final count = _database.choirMembers.choirId.count();
    final query = _database.selectOnly(_database.choirMembers)
      ..addColumns([count])
      ..where(_database.choirMembers.choirId.equals(choirId));

    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Get all unsynced choirs
  ///
  /// Used by sync service to find choirs that need to be synced to cloud.
  Future<List<ChoirModel>> getUnsyncedChoirs() async {
    final choirs = await (_database.select(_database.choirs)
          ..where((c) => c.synced.equals(false)))
        .get();

    return choirs.map((c) => ChoirModel.fromDrift(c)).toList();
  }

  /// Mark choir as synced to cloud
  ///
  /// Called by sync service after successfully uploading to Supabase.
  Future<void> markChoirAsSynced(String id) async {
    await (_database.update(_database.choirs)..where((c) => c.id.equals(id)))
        .write(const db.ChoirsCompanion(synced: Value(true)));
  }

  /// Get all unsynced choir members
  ///
  /// Used by sync service to find memberships that need to be synced to cloud.
  Future<List<ChoirMemberModel>> getUnsyncedMembers() async {
    final members = await (_database.select(_database.choirMembers)
          ..where((m) => m.synced.equals(false)))
        .get();

    return members.map((m) => ChoirMemberModel.fromDrift(m)).toList();
  }

  /// Mark choir member as synced to cloud
  ///
  /// Called by sync service after successfully uploading to Supabase.
  Future<void> markMemberAsSynced(String choirId, String userId) async {
    await (_database.update(_database.choirMembers)
          ..where((m) => m.choirId.equals(choirId))
          ..where((m) => m.userId.equals(userId)))
        .write(const db.ChoirMembersCompanion(synced: Value(true)));
  }

  /// Hard-delete synced choirs whose IDs are NOT in the provided set
  ///
  /// Called after pull phase to remove choirs that exist locally but were
  /// deleted remotely. Only synced choirs are deleted to avoid losing unsynced changes.
  Future<void> hardDeleteSyncedChoirsNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) {
      // Delete all synced choirs
      await (_database.delete(_database.choirs)
            ..where((c) => c.synced.equals(true)))
          .go();
    } else {
      // Delete synced choirs not in the keep set
      await (_database.delete(_database.choirs)
            ..where((c) => c.synced.equals(true))
            ..where((c) => c.id.isNotIn(keepIds)))
          .go();
    }
  }

  /// Hard-delete synced choirs that are soft-deleted
  ///
  /// Called after push phase to clean up choirs that were successfully deleted
  /// on remote. Only synced+deleted choirs are removed.
  Future<void> hardDeleteSyncedDeletedChoirs() async {
    await (_database.delete(_database.choirs)
          ..where((c) => c.synced.equals(true))
          ..where((c) => c.deleted.equals(true)))
        .go();
  }

  /// Hard-delete synced choir members whose composite keys are NOT in the provided set
  ///
  /// Called after pull phase to remove memberships that exist locally but were
  /// deleted remotely. Only synced members are deleted.
  /// [keepIds] should contain strings in format "choirId:userId"
  Future<void> hardDeleteSyncedMembersNotIn(Set<String> keepIds) async {
    // Get all synced members
    final syncedMembers = await (_database.select(_database.choirMembers)
          ..where((m) => m.synced.equals(true)))
        .get();

    // Delete those not in keep set
    for (final member in syncedMembers) {
      final compositeId = '${member.choirId}:${member.userId}';
      if (!keepIds.contains(compositeId)) {
        await (_database.delete(_database.choirMembers)
              ..where((m) => m.choirId.equals(member.choirId))
              ..where((m) => m.userId.equals(member.userId)))
            .go();
      }
    }
  }

  /// Hard-delete synced choir members that are soft-deleted
  ///
  /// Called after push phase to clean up memberships that were successfully
  /// deleted on remote. Only synced+deleted members are removed.
  Future<void> hardDeleteSyncedDeletedMembers() async {
    await (_database.delete(_database.choirMembers)
          ..where((m) => m.synced.equals(true))
          ..where((m) => m.deleted.equals(true)))
        .go();
  }

  /// Get all synced choirs as a map (ID -> ChoirModel)
  ///
  /// Used during pull phase to avoid re-pulling items that are already up-to-date.
  Future<Map<String, ChoirModel>> getSyncedChoirs() async {
    final choirs = await (_database.select(_database.choirs)
          ..where((c) => c.synced.equals(true)))
        .get();

    return Map.fromEntries(
      choirs.map((c) => MapEntry(c.id, ChoirModel.fromDrift(c))),
    );
  }

  /// Get all synced choir members as a map (compositeId -> ChoirMemberModel)
  ///
  /// Used during pull phase to avoid re-pulling items that are already up-to-date.
  /// Map keys are in format "choirId:userId"
  Future<Map<String, ChoirMemberModel>> getSyncedMembers() async {
    final members = await (_database.select(_database.choirMembers)
          ..where((m) => m.synced.equals(true)))
        .get();

    return Map.fromEntries(
      members.map((m) => MapEntry(
            '${m.choirId}:${m.userId}',
            ChoirMemberModel.fromDrift(m),
          )),
    );
  }

  // ============================================================================
  // TESTING/ADMIN OPERATIONS
  // ============================================================================

  /// Clear all choir data (for testing)
  ///
  /// Permanently deletes all choirs and memberships. Use with caution!
  Future<void> clearAll() async {
    await _database.transaction(() async {
      await _database.delete(_database.choirMembers).go();
      await _database.delete(_database.choirs).go();
    });
  }
}
