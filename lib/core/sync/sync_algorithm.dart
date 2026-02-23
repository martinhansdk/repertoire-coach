import 'dart:developer' as developer;

import 'sync_adapter.dart';
import 'syncable.dart';

/// Generic bidirectional sync algorithm.
///
/// Implements the "push-before-pull, newest-wins" sync strategy:
/// 1. Push phase: Send local changes to remote (creates, updates, deletes)
/// 2. Pull phase: Fetch remote items and upsert locally
/// 3. Cleanup: Remove stale local items that were deleted remotely
///
/// The algorithm is generic and works with any entity type that implements
/// [Syncable] and has a corresponding [SyncAdapter].
class SyncAlgorithm<T extends Syncable> {
  final SyncAdapter<T> adapter;

  SyncAlgorithm(this.adapter);

  /// Performs bidirectional sync between local and remote storage.
  ///
  /// Returns a [SyncResult] containing counts of operations performed.
  Future<SyncResult> sync() async {
    // Counters for result
    int pushedCreates = 0;
    int pushedUpdates = 0;
    int pushedDeletes = 0;
    int pulled = 0;
    int pushFailures = 0;

    // Track which items were successfully pushed (to skip during pull)
    final pushedIds = <String>{};
    // Track items whose push failed — skip them during pull so a transient
    // push failure doesn't cause the pull phase to overwrite local changes.
    final failedPushIds = <String>{};

    try {
      // Step 1: Fetch local items and all remote items
      final unsyncedLocal = await adapter.getUnsyncedLocal();
      final syncedLocal = await adapter.getSyncedLocal();
      final allRemote = await adapter.getAllRemote();

      // Build a map of remote items by ID for quick lookup
      final remoteById = <String, T>{};
      for (final item in allRemote) {
        remoteById[item.syncId] = item;
      }

      // Step 2: Push phase - send local changes to remote
      for (final localItem in unsyncedLocal) {
        final id = localItem.syncId;
        final remoteItem = remoteById[id];

        try {
          if (adapter.isLocallyDeleted(localItem)) {
            // Local item is soft-deleted - delete on remote if it exists
            if (remoteItem != null) {
              await adapter.deleteOnRemote(id);
              pushedDeletes++;
              // Remove from remoteById so it's not in cleanup check
              remoteById.remove(id);
            }
            // Mark as synced so it gets hard-deleted in cleanup
            await adapter.markSynced(id);
            pushedIds.add(id);
          } else if (remoteItem == null) {
            // Item exists locally but not remotely - create
            await adapter.createOnRemote(localItem);
            await adapter.markSynced(id);
            pushedCreates++;
            pushedIds.add(id);
            // Add to remoteById so cleanup doesn't delete it
            remoteById[id] = localItem;
          } else {
            // Item exists on both sides - check timestamps
            if (localItem.syncTimestamp.isAfter(remoteItem.syncTimestamp)) {
              // Local is newer - update remote
              await adapter.updateOnRemote(localItem);
              await adapter.markSynced(id);
              pushedUpdates++;
              pushedIds.add(id);
              // Update remoteById with the new version
              remoteById[id] = localItem;
            } else {
              // Remote is newer or equal - upsert immediately, mark synced, skip pull
              await adapter.upsertLocal(remoteItem);
              await adapter.markSynced(id);
              pulled++;
              pushedIds.add(id);
            }
          }
        } catch (e) {
          // Push failed for this item - log and continue with others
          // Item stays unsynced and will be retried on next sync.
          // Record the failure so the pull phase doesn't overwrite local changes.
          developer.log(
            'Failed to push item $id: $e',
            name: 'SyncAlgorithm',
            error: e,
          );
          failedPushIds.add(id);
          pushFailures++;
        }
      }

      // Step 3: Hard-delete synced items that were soft-deleted locally
      await adapter.hardDeleteSyncedDeleted();

      // Step 4: Pull phase - upsert remote items that we didn't handle in push
      for (final remoteItem in allRemote) {
        final id = remoteItem.syncId;

        // Skip items we already handled in push phase, and items whose push
        // failed (we don't want a transient failure to overwrite local changes).
        if (pushedIds.contains(id) || failedPushIds.contains(id)) {
          continue;
        }

        // Skip items that already exist locally with same or newer timestamp
        final syncedItem = syncedLocal[id];
        if (syncedItem != null &&
            !syncedItem.syncTimestamp.isBefore(remoteItem.syncTimestamp)) {
          continue;
        }

        await adapter.upsertLocal(remoteItem);
        pulled++;
      }

      // Step 5: Hard-delete synced local items that don't exist remotely
      final remoteIds = remoteById.keys.toSet();
      await adapter.hardDeleteSyncedNotIn(remoteIds);

      return SyncResult(
        pushedCreates: pushedCreates,
        pushedUpdates: pushedUpdates,
        pushedDeletes: pushedDeletes,
        pulled: pulled,
        pushFailures: pushFailures,
      );
    } catch (e) {
      // Fatal error during sync - log and rethrow
      developer.log(
        'Sync failed: $e',
        name: 'SyncAlgorithm',
        error: e,
      );
      rethrow;
    }
  }
}
