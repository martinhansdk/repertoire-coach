import 'package:repertoire_coach/core/sync/sync_adapter.dart';
import 'package:repertoire_coach/core/sync/syncable.dart';

/// A fake item for testing the sync algorithm.
///
/// Contains the minimum required fields (id, timestamp, data) plus
/// local-only metadata (synced, deleted).
class FakeItem with Syncable {
  @override
  final String syncId;

  @override
  final DateTime syncTimestamp;

  /// Arbitrary payload to verify content propagation.
  ///
  /// This field ensures the sync algorithm correctly transfers data,
  /// not just IDs and timestamps.
  final String data;

  /// Whether this item is soft-deleted locally (local-only field).
  final bool deleted;

  const FakeItem({
    required this.syncId,
    required this.syncTimestamp,
    required this.data,
    this.deleted = false,
  });

  /// Creates a copy with updated fields.
  FakeItem copyWith({
    String? syncId,
    DateTime? syncTimestamp,
    String? data,
    bool? deleted,
  }) {
    return FakeItem(
      syncId: syncId ?? this.syncId,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      data: data ?? this.data,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FakeItem &&
          runtimeType == other.runtimeType &&
          syncId == other.syncId &&
          syncTimestamp == other.syncTimestamp &&
          data == other.data &&
          deleted == other.deleted;

  @override
  int get hashCode =>
      syncId.hashCode ^
      syncTimestamp.hashCode ^
      data.hashCode ^
      deleted.hashCode;

  @override
  String toString() => 'FakeItem('
      'id: $syncId, '
      'timestamp: $syncTimestamp, '
      'data: $data, '
      'deleted: $deleted)';
}

/// Local storage record with sync metadata.
typedef LocalRecord = ({FakeItem item, bool synced});

/// In-memory fake adapter for testing sync algorithm.
///
/// Simulates both local and remote storage using in-memory maps.
/// Supports injecting push failures for specific IDs.
class FakeSyncAdapter implements SyncAdapter<FakeItem> {
  /// Local storage: ID -> (item, synced flag)
  final Map<String, LocalRecord> local = {};

  /// Remote storage: ID -> item
  final Map<String, FakeItem> remote = {};

  /// IDs that should fail when pushed to remote.
  ///
  /// Useful for testing error handling and retry logic.
  final Set<String> failingIds = {};

  @override
  Future<List<FakeItem>> getUnsyncedLocal() async {
    return local.entries
        .where((e) => !e.value.synced)
        .map((e) => e.value.item)
        .toList();
  }

  @override
  Future<Map<String, FakeItem>> getSyncedLocal() async {
    return Map.fromEntries(
      local.entries
          .where((e) => e.value.synced)
          .map((e) => MapEntry(e.key, e.value.item)),
    );
  }

  @override
  Future<List<FakeItem>> getAllRemote() async {
    return remote.values.toList();
  }

  @override
  bool isLocallyDeleted(FakeItem item) {
    return item.deleted;
  }

  @override
  Future<void> createOnRemote(FakeItem item) async {
    if (failingIds.contains(item.syncId)) {
      throw Exception('Simulated push failure for ${item.syncId}');
    }
    // Create on remote (without deleted flag - remote doesn't track this)
    remote[item.syncId] = item.copyWith(deleted: false);
  }

  @override
  Future<void> updateOnRemote(FakeItem item) async {
    if (failingIds.contains(item.syncId)) {
      throw Exception('Simulated push failure for ${item.syncId}');
    }
    // Update on remote (without deleted flag)
    remote[item.syncId] = item.copyWith(deleted: false);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    if (failingIds.contains(id)) {
      throw Exception('Simulated push failure for $id');
    }
    remote.remove(id);
  }

  @override
  Future<void> markSynced(String id) async {
    final record = local[id];
    if (record != null) {
      local[id] = (item: record.item, synced: true);
    }
  }

  @override
  Future<void> upsertLocal(FakeItem item) async {
    final existing = local[item.syncId];

    // Critical behavior: Don't resurrect items with pending soft-deletes
    if (existing != null &&
        existing.item.deleted &&
        !existing.synced) {
      // Item has unsynced soft-delete - skip upsert
      return;
    }

    // Upsert the item (mark as synced since it came from remote)
    local[item.syncId] = (
      item: item.copyWith(deleted: false),
      synced: true,
    );
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    final idsToDelete = local.keys
        .where((id) => local[id]!.synced && !keepIds.contains(id))
        .toList();

    for (final id in idsToDelete) {
      local.remove(id);
    }
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    final idsToDelete = local.entries
        .where((e) => e.value.synced && e.value.item.deleted)
        .map((e) => e.key)
        .toList();

    for (final id in idsToDelete) {
      local.remove(id);
    }
  }

  // Helper methods for tests

  /// Adds an item to local storage.
  void addLocal(FakeItem item, {bool synced = false}) {
    local[item.syncId] = (item: item, synced: synced);
  }

  /// Adds an item to remote storage.
  void addRemote(FakeItem item) {
    remote[item.syncId] = item.copyWith(deleted: false);
  }

  /// Creates a FakeItem with default values.
  FakeItem createItem({
    required String id,
    DateTime? timestamp,
    String? data,
    bool deleted = false,
  }) {
    return FakeItem(
      syncId: id,
      syncTimestamp: timestamp ?? DateTime(2024, 1, 1),
      data: data ?? 'data-$id',
      deleted: deleted,
    );
  }
}
