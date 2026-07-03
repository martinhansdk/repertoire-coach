import '../../core/services/error_reporter.dart';
import 'sync_adapter.dart';
import 'syncable.dart';

/// Generic bidirectional sync algorithm.
///
/// Implements "push-before-pull, newest edit wins":
/// 1. Push phase: for each locally-unsynced item, compare edit timestamps with
///    the remote copy and let the newest change win — including deletions,
///    which are ordinary tombstone rows (deleted=true), not row absence.
/// 2. Pull phase: upsert remote items (including tombstones) that are newer
///    than the local copy.
/// 3. Purge: hard-delete local rows that are synced AND soft-deleted; their
///    tombstone has been fully applied on both sides.
///
/// Deletion is NEVER inferred from absence. A row missing from
/// [SyncAdapter.getAllRemote] (partial reads, row limits, RLS, empty
/// membership chains) simply means "no information", so incomplete remote
/// reads can no longer destroy local data.
class SyncAlgorithm<T extends Syncable> {
  final SyncAdapter<T> adapter;

  SyncAlgorithm(this.adapter);

  /// Performs bidirectional sync between local and remote storage.
  ///
  /// Returns a [SyncResult] containing counts of operations performed.
  Future<SyncResult> sync() async {
    int pushedCreates = 0;
    int pushedUpdates = 0;
    int pushedDeletes = 0;
    int pulled = 0;
    int pushFailures = 0;

    // Items handled during the push phase (skip during pull).
    final handledIds = <String>{};
    // Items whose push failed — also skipped during pull so a transient
    // failure doesn't cause the pull phase to overwrite local changes.
    final failedPushIds = <String>{};

    try {
      // Step 1: Snapshot local and remote state.
      final unsyncedLocal = await adapter.getUnsyncedLocal();
      final syncedLocal = await adapter.getSyncedLocal();
      final allRemote = await adapter.getAllRemote();

      final remoteById = <String, T>{
        for (final item in allRemote) item.syncId: item,
      };

      // Step 2: Push phase — resolve every locally-unsynced item.
      for (final localItem in unsyncedLocal) {
        final id = localItem.syncId;
        final remoteItem = remoteById[id];

        try {
          final remoteIsNewer = remoteItem != null &&
              remoteItem.syncTimestamp.isAfter(localItem.syncTimestamp);

          if (remoteIsNewer) {
            // Remote change (edit or tombstone) is newer than the local one —
            // remote wins, even over a local deletion. upsertLocal writes it
            // with synced=true; if it is a tombstone the purge step removes it.
            await adapter.upsertLocal(remoteItem);
            pulled++;
          } else if (localItem.isDeleted) {
            // Local deletion wins (or remote never saw this item).
            if (remoteItem != null && !remoteItem.isDeleted) {
              await adapter.deleteOnRemote(id, localItem.syncTimestamp);
              pushedDeletes++;
            }
            // Conditional: fails harmlessly if the row changed mid-sync.
            await adapter.markSynced(id, localItem.syncTimestamp);
          } else if (remoteItem == null) {
            // Exists locally, never seen remotely — create. (If the item was
            // tombstoned remotely, it IS in allRemote and handled above.)
            await adapter.createOnRemote(localItem);
            await adapter.markSynced(id, localItem.syncTimestamp);
            pushedCreates++;
          } else {
            // Local edit is newer than (or as new as) remote — local wins.
            // updateOnRemote writes deleted=false, so a newer local edit
            // deliberately overrides an older remote tombstone.
            await adapter.updateOnRemote(localItem);
            await adapter.markSynced(id, localItem.syncTimestamp);
            pushedUpdates++;
          }
          handledIds.add(id);
        } catch (e, st) {
          // Push failed for this item — log and continue with others.
          // Item stays unsynced and will be retried on next sync.
          ErrorReporter.report(e, stackTrace: st, screen: 'sync');
          failedPushIds.add(id);
          pushFailures++;
        }
      }

      // Step 3: Pull phase — apply remote items not handled above.
      for (final remoteItem in allRemote) {
        final id = remoteItem.syncId;

        if (handledIds.contains(id) || failedPushIds.contains(id)) {
          continue;
        }

        // Skip items that already exist locally with same or newer timestamp.
        final syncedItem = syncedLocal[id];
        if (syncedItem != null &&
            !syncedItem.syncTimestamp.isBefore(remoteItem.syncTimestamp)) {
          continue;
        }

        // Tombstones for items we've never had (or already purged): nothing
        // to apply locally, and upserting would briefly resurrect the row.
        if (remoteItem.isDeleted && syncedItem == null) {
          continue;
        }

        await adapter.upsertLocal(remoteItem);
        pulled++;
      }

      // Step 4: Purge fully-applied tombstones (synced AND deleted).
      await adapter.hardDeleteSyncedDeleted();

      return SyncResult(
        pushedCreates: pushedCreates,
        pushedUpdates: pushedUpdates,
        pushedDeletes: pushedDeletes,
        pulled: pulled,
        pushFailures: pushFailures,
      );
    } catch (e, st) {
      // Fatal error during sync — log and rethrow.
      ErrorReporter.report(e, stackTrace: st, screen: 'sync');
      rethrow;
    }
  }
}
