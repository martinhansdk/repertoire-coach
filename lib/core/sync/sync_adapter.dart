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

  /// Returns true if the given item is soft-deleted locally.
  ///
  /// Soft-deleted items should be pushed as deletes to remote, then
  /// hard-deleted locally once synced.
  bool isLocallyDeleted(T item);

  /// Creates the item on remote storage.
  ///
  /// Called during push phase for items that exist locally but not remotely.
  Future<void> createOnRemote(T item);

  /// Updates the item on remote storage.
  ///
  /// Called during push phase when local version is newer than remote.
  Future<void> updateOnRemote(T item);

  /// Deletes the item from remote storage.
  ///
  /// Called during push phase for soft-deleted local items.
  Future<void> deleteOnRemote(String id);

  /// Marks the local item as synced.
  ///
  /// Called after successful push operations to indicate the item is now
  /// in sync with remote.
  Future<void> markSynced(String id);

  /// Upserts the item into local storage.
  ///
  /// Called during pull phase for remote items. Should insert if the item
  /// doesn't exist locally, or update if it does.
  ///
  /// **Important**: If the local item exists and has an unsynced soft-delete
  /// (deleted=true, synced=false), the upsert should be skipped to avoid
  /// resurrecting a deleted item.
  Future<void> upsertLocal(T item);

  /// Hard-deletes all synced local items whose IDs are NOT in [keepIds].
  ///
  /// Called after pull phase to clean up items that exist locally but were
  /// deleted remotely. Only synced items should be deleted; unsynced items
  /// stay for the next sync attempt.
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds);

  /// Hard-deletes all synced items that are soft-deleted locally.
  ///
  /// Called after push phase to clean up items that were successfully deleted
  /// on remote. Only synced+deleted items are removed; unsynced deleted items
  /// stay for retry.
  Future<void> hardDeleteSyncedDeleted();
}
