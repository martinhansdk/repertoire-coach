import 'package:repertoire_coach/core/sync/sync_adapter.dart';
import 'package:repertoire_coach/core/sync/syncable.dart';

/// A fake item for testing the sync algorithm.
///
/// Contains the minimum required fields (id, timestamp, data) plus the
/// deleted flag, which — like in the real schema since migration 013 —
/// exists on BOTH sides: locally as the soft-delete marker and remotely as
/// the tombstone.
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

  /// Whether this item is soft-deleted (a tombstone).
  final bool deleted;

  @override
  bool get isDeleted => deleted;

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

/// In-memory fake adapter for testing the sync algorithm.
///
/// Simulates both local and remote storage using in-memory maps, mirroring
/// the semantics of the real Drift/Supabase datasources:
///  - the remote holds tombstones (rows with deleted=true), never removes rows
///  - [markSynced] is CONDITIONAL on the snapshotted timestamp
///  - [upsertLocal] refuses to overwrite an unsynced local row that is not
///    older than the incoming one
///
/// Supports injecting push failures for specific IDs and mutation hooks to
/// simulate user edits that land in the middle of a sync run.
class FakeSyncAdapter implements SyncAdapter<FakeItem> {
  /// Local storage: ID -> (item, synced flag)
  final Map<String, LocalRecord> local = {};

  /// Remote storage: ID -> item (including tombstones).
  ///
  /// Pass [sharedRemote] to make several adapters ("devices") operate on one
  /// shared remote store, PostgREST-style. Remote writes go through
  /// immediately, so another device syncing later observes them.
  final Map<String, FakeItem> remote;

  FakeSyncAdapter({Map<String, FakeItem>? sharedRemote})
      : remote = sharedRemote ?? {};

  /// IDs that should fail when pushed to remote.
  ///
  /// Useful for testing error handling and retry logic.
  final Set<String> failingIds = {};

  /// When true, [getAllRemote] returns an empty list regardless of [remote].
  ///
  /// Simulates a partial/failed remote read (empty membership chain, RLS
  /// hiccup, PostgREST row limit) that used to be indistinguishable from
  /// "everything was deleted remotely".
  bool remoteReadReturnsEmpty = false;

  /// Invoked just before [markSynced] applies; lets tests mutate [local] to
  /// simulate a user edit racing the sync run.
  void Function(String id)? onBeforeMarkSynced;

  /// Invoked just before [upsertLocal] applies; lets tests mutate [local] to
  /// simulate a user edit racing the pull phase.
  void Function(FakeItem incoming)? onBeforeUpsertLocal;

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
    if (remoteReadReturnsEmpty) return [];
    return remote.values.toList();
  }

  @override
  Future<void> createOnRemote(FakeItem item) async {
    if (failingIds.contains(item.syncId)) {
      throw Exception('Simulated push failure for ${item.syncId}');
    }
    // Faithful to Postgres: INSERT on an existing key fails. This matters
    // when a partial remote read makes the algorithm believe an item is new:
    // the create must fail (and be retried) rather than silently overwrite.
    if (remote.containsKey(item.syncId)) {
      throw Exception(
          'duplicate key: ${item.syncId} already exists on remote');
    }
    remote[item.syncId] = item;
  }

  @override
  Future<void> updateOnRemote(FakeItem item) async {
    if (failingIds.contains(item.syncId)) {
      throw Exception('Simulated push failure for ${item.syncId}');
    }
    // Like the real datasources, an update writes deleted (false here, since
    // the algorithm only pushes updates for live items) — a newer edit
    // deliberately clears a remote tombstone.
    remote[item.syncId] = item;
  }

  @override
  Future<void> deleteOnRemote(String id, DateTime deletedAt) async {
    if (failingIds.contains(id)) {
      throw Exception('Simulated push failure for $id');
    }
    // Soft delete: the remote row becomes a tombstone stamped with the local
    // deletion time. Rows are never removed.
    final existing = remote[id];
    remote[id] = (existing ??
            FakeItem(syncId: id, syncTimestamp: deletedAt, data: ''))
        .copyWith(deleted: true, syncTimestamp: deletedAt);
  }

  @override
  Future<void> markSynced(String id, DateTime expectedUpdatedAt) async {
    onBeforeMarkSynced?.call(id);
    final record = local[id];
    // Conditional, like the real datasources: only mark synced if the row
    // still carries the timestamp the sync run snapshotted.
    if (record != null && record.item.syncTimestamp == expectedUpdatedAt) {
      local[id] = (item: record.item, synced: true);
    }
  }

  @override
  Future<void> upsertLocal(FakeItem item) async {
    onBeforeUpsertLocal?.call(item);
    final existing = local[item.syncId];

    // An unsynced local change (edit or soft-delete) that is not older than
    // the incoming row wins locally; it is resolved against remote on the
    // next push phase instead of being overwritten here.
    if (existing != null &&
        !existing.synced &&
        !existing.item.syncTimestamp.isBefore(item.syncTimestamp)) {
      return;
    }

    local[item.syncId] = (item: item, synced: true);
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
    remote[item.syncId] = item;
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
