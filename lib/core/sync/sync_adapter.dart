import 'syncable.dart';

/// Result of a sync operation containing counts of various operations performed.
class SyncResult {
  /// Number of items created on remote during push phase.
  final int pushedCreates;

  /// Number of items updated on remote during push phase.
  final int pushedUpdates;

  /// Number of items deleted on remote during push phase.
  final int pushedDeletes;

  /// Number of items pulled from remote and upserted locally.
  final int pulled;

  /// Number of push operations that failed.
  ///
  /// Failed items remain unsynced and will be retried on next sync.
  final int pushFailures;

  const SyncResult({
    required this.pushedCreates,
    required this.pushedUpdates,
    required this.pushedDeletes,
    required this.pulled,
    required this.pushFailures,
  });

  /// Creates a result with all counts set to zero.
  const SyncResult.empty()
      : pushedCreates = 0,
        pushedUpdates = 0,
        pushedDeletes = 0,
        pulled = 0,
        pushFailures = 0;

  @override
  String toString() => 'SyncResult('
      'pushed: $pushedCreates creates, $pushedUpdates updates, $pushedDeletes deletes; '
      'pulled: $pulled; '
      'failures: $pushFailures)';
}

/// Adapter interface for syncing entities between local and remote storage.
///
/// Each entity type implements this interface to provide entity-specific I/O
/// operations. The generic [SyncAlgorithm] uses these adapters to perform
/// bidirectional sync without knowing about specific entity types.
abstract class SyncAdapter<T extends Syncable> {
  /// Fetches all unsynced items from local storage.
  ///
  /// Unsynced items are those that have been created, updated, or soft-deleted
  /// locally but not yet pushed to remote.
  Future<List<T>> getUnsyncedLocal();

  /// Returns synced local items as a map (ID -> item).
  ///
  /// Used during pull phase to avoid re-pulling items that are already up-to-date locally.
  Future<Map<String, T>> getSyncedLocal();

  /// Fetches all items from remote storage.
  ///
  /// This includes all items that exist on the remote side, regardless of
  /// whether they exist locally.
  Future<List<T>> getAllRemote();

  /// Creates the item on remote storage.
  ///
  /// Called during push phase for items that exist locally but not remotely.
  Future<void> createOnRemote(T item);

  /// Updates the item on remote storage.
  ///
  /// Called during push phase when local version is newer than remote.
  Future<void> updateOnRemote(T item);

  /// Soft-deletes the item on remote storage (sets deleted=true).
  ///
  /// Called during push phase for soft-deleted local items. [deletedAt] is the
  /// local deletion timestamp and must be written to the remote row's
  /// updated_at so the tombstone participates in newest-wins like any edit.
  Future<void> deleteOnRemote(String id, DateTime deletedAt);

  /// Marks the local item as synced, but only if it has not been modified
  /// since the sync run snapshotted it.
  ///
  /// Implementations must make the write conditional
  /// (`WHERE id = ? AND updated_at = expectedUpdatedAt`). If the user edited
  /// the item mid-sync, the condition fails, the row stays unsynced, and the
  /// new edit is pushed on the next run instead of being silently dropped.
  Future<void> markSynced(String id, DateTime expectedUpdatedAt);

  /// Upserts the item into local storage.
  ///
  /// Called during pull phase for remote items. Should insert if the item
  /// doesn't exist locally, or update if it does.
  ///
  /// **Important**: If the local item exists and is unsynced with a timestamp
  /// equal to or newer than [item] (including unsynced soft-deletes), the
  /// upsert must be skipped: the local change wins locally and will be
  /// resolved against remote during the next push phase.
  Future<void> upsertLocal(T item);

  /// Hard-deletes all synced items that are soft-deleted locally.
  ///
  /// Called at the end of a sync run to purge fully-applied tombstones
  /// (both locally-initiated deletions that were pushed, and remote tombstones
  /// that were pulled). Only synced+deleted rows are removed; unsynced deleted
  /// rows stay for retry.
  Future<void> hardDeleteSyncedDeleted();
}
