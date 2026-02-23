import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/sync/sync_algorithm.dart';

import 'fake_sync_adapter.dart';

void main() {
  group('SyncAlgorithm - deterministic tests', () {
    late FakeSyncAdapter adapter;
    late SyncAlgorithm<FakeItem> algorithm;

    setUp(() {
      adapter = FakeSyncAdapter();
      algorithm = SyncAlgorithm(adapter);
    });

    test('1. both sides empty -> no-op', () async {
      final result = await algorithm.sync();

      expect(result.pushedCreates, 0);
      expect(result.pushedUpdates, 0);
      expect(result.pushedDeletes, 0);
      expect(result.pulled, 0);
      expect(result.pushFailures, 0);
      expect(adapter.local, isEmpty);
      expect(adapter.remote, isEmpty);
    });

    test('2. local only -> push all', () async {
      final item1 = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 1),
      );
      final item2 = adapter.createItem(
        id: 'item2',
        timestamp: DateTime(2024, 1, 2),
      );

      adapter.addLocal(item1, synced: false);
      adapter.addLocal(item2, synced: false);

      final result = await algorithm.sync();

      expect(result.pushedCreates, 2);
      expect(result.pushedUpdates, 0);
      expect(result.pushedDeletes, 0);
      expect(result.pulled, 0);
      expect(result.pushFailures, 0);

      // Both items now on remote
      expect(adapter.remote.length, 2);
      expect(adapter.remote['item1']!.data, item1.data);
      expect(adapter.remote['item2']!.data, item2.data);

      // Both marked as synced locally
      expect(adapter.local['item1']!.synced, true);
      expect(adapter.local['item2']!.synced, true);
    });

    test('3. remote only -> pull all', () async {
      final item1 = adapter.createItem(id: 'item1');
      final item2 = adapter.createItem(id: 'item2');

      adapter.addRemote(item1);
      adapter.addRemote(item2);

      final result = await algorithm.sync();

      expect(result.pushedCreates, 0);
      expect(result.pulled, 2);

      // Both items now in local
      expect(adapter.local.length, 2);
      expect(adapter.local['item1']!.item.data, item1.data);
      expect(adapter.local['item2']!.item.data, item2.data);

      // Pulled items are marked synced
      expect(adapter.local['item1']!.synced, true);
      expect(adapter.local['item2']!.synced, true);
    });

    test('4. same item, local newer -> push wins', () async {
      final localItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 2),
        data: 'local-data',
      );
      final remoteItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 1),
        data: 'remote-data',
      );

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      expect(result.pushedUpdates, 1);
      expect(result.pulled, 0);

      // Remote updated with local data
      expect(adapter.remote['item1']!.data, 'local-data');
      expect(adapter.remote['item1']!.syncTimestamp, DateTime(2024, 1, 2));

      // Local marked as synced
      expect(adapter.local['item1']!.synced, true);
    });

    test('5. same item, remote newer -> pull wins', () async {
      final localItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 1),
        data: 'local-data',
      );
      final remoteItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 2),
        data: 'remote-data',
      );

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      expect(result.pushedUpdates, 0);
      expect(result.pulled, 1);

      // Local updated with remote data
      expect(adapter.local['item1']!.item.data, 'remote-data');
      expect(
        adapter.local['item1']!.item.syncTimestamp,
        DateTime(2024, 1, 2),
      );

      // Remote unchanged
      expect(adapter.remote['item1']!.data, 'remote-data');

      // Local marked as synced
      expect(adapter.local['item1']!.synced, true);
    });

    test('6. same item, identical timestamps -> no change', () async {
      final timestamp = DateTime(2024, 1, 1);
      final localItem = adapter.createItem(
        id: 'item1',
        timestamp: timestamp,
        data: 'local-data',
      );
      final remoteItem = adapter.createItem(
        id: 'item1',
        timestamp: timestamp,
        data: 'remote-data',
      );

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      // Local marked as synced but not pushed (timestamps equal)
      expect(result.pushedUpdates, 0);
      expect(result.pulled, 1);

      // Local gets remote version (pull wins on tie)
      expect(adapter.local['item1']!.item.data, 'remote-data');
      expect(adapter.local['item1']!.synced, true);
    });

    test('7. local soft-deleted unsynced -> push delete, hard-delete locally',
        () async {
      final localItem = adapter.createItem(
        id: 'item1',
        deleted: true,
      );
      final remoteItem = adapter.createItem(id: 'item1');

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 1);

      // Remote item deleted
      expect(adapter.remote.containsKey('item1'), false);

      // Local item hard-deleted
      expect(adapter.local.containsKey('item1'), false);
    });

    test('8. local soft-deleted synced -> hard-delete locally', () async {
      final localItem = adapter.createItem(
        id: 'item1',
        deleted: true,
      );

      adapter.addLocal(localItem, synced: true);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 0);

      // Local item hard-deleted (was already synced)
      expect(adapter.local.containsKey('item1'), false);
    });

    test('9. push failure -> item stays unsynced, others sync', () async {
      final item1 = adapter.createItem(id: 'item1');
      final item2 = adapter.createItem(id: 'item2');

      adapter.addLocal(item1, synced: false);
      adapter.addLocal(item2, synced: false);

      // Inject failure for item1
      adapter.failingIds.add('item1');

      final result = await algorithm.sync();

      expect(result.pushedCreates, 1); // Only item2 succeeded
      expect(result.pushFailures, 1); // item1 failed

      // item2 pushed and synced
      expect(adapter.remote.containsKey('item2'), true);
      expect(adapter.local['item2']!.synced, true);

      // item1 NOT pushed and stays unsynced
      expect(adapter.remote.containsKey('item1'), false);
      expect(adapter.local['item1']!.synced, false);
    });

    test('10. synced local item not in remote -> hard-deleted', () async {
      final localItem = adapter.createItem(id: 'item1');

      adapter.addLocal(localItem, synced: true);

      final result = await algorithm.sync();

      expect(result.pushedCreates, 0);
      expect(result.pulled, 0);

      // Local item hard-deleted (doesn't exist on remote)
      expect(adapter.local.containsKey('item1'), false);
    });

    test('11. soft-deleted locally, still on remote -> push delete', () async {
      final localItem = adapter.createItem(
        id: 'item1',
        deleted: true,
      );
      final remoteItem = adapter.createItem(id: 'item1');

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 1);

      // Remote deleted
      expect(adapter.remote.containsKey('item1'), false);

      // Local hard-deleted
      expect(adapter.local.containsKey('item1'), false);
    });

    test('12. same ID both sides, different data -> newest wins', () async {
      final localItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 2),
        data: 'local-wins',
      );
      final remoteItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 1),
        data: 'remote-loses',
      );

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      expect(result.pushedUpdates, 1);

      // Remote has local's data (local was newer)
      expect(adapter.remote['item1']!.data, 'local-wins');

      // Local unchanged
      expect(adapter.local['item1']!.item.data, 'local-wins');
    });

    test('13. double sync is no-op', () async {
      final item1 = adapter.createItem(id: 'item1');
      final item2 = adapter.createItem(id: 'item2');

      adapter.addLocal(item1, synced: false);
      adapter.addRemote(item2);

      // First sync
      final result1 = await algorithm.sync();

      expect(result1.pushedCreates, 1);
      expect(result1.pulled, 1);

      // Second sync should do nothing
      final result2 = await algorithm.sync();

      expect(result2.pushedCreates, 0);
      expect(result2.pushedUpdates, 0);
      expect(result2.pushedDeletes, 0);
      expect(result2.pulled, 0);
      expect(result2.pushFailures, 0);

      // State unchanged
      expect(adapter.local.length, 2);
      expect(adapter.remote.length, 2);
    });

    // Regression test for the marker-set reversion bug (2026-02-22).
    //
    // Root cause chain:
    //   1. RemoteMarkerDataSource.updateMarkerSet() sent markers_json as a raw
    //      Dart String.  PostgREST stored it as a JSONB scalar string; the
    //      migration-012 CHECK constraint called jsonb_array_elements() on it
    //      and threw "cannot extract elements from a scalar", rejecting every
    //      update silently.
    //   2. Because both direct pushes in the repository failed, remote kept the
    //      old markers_json.
    //   3. On sync, local was newer (T3) than remote (T_old), so the push phase
    //      called updateOnRemote — which also failed for the same reason.
    //   4. Bug 3 (pre-fix): the push catch block did NOT add the item to
    //      pushedIds, so the pull phase saw syncedLocal[id]=null (item was
    //      unsynced) and called upsertLocal(remote_old) — overwriting the user's
    //      local changes with the old server data.  Visible as the marker set
    //      reverting after sync.
    //
    // The fix: add failedPushIds and skip those in the pull phase.
    // This test must fail if the failedPushIds guard is removed.
    test(
        '14. regression: push failure does not overwrite local data with stale remote',
        () async {
      // Local: user just saved the marker set → unsynced, newer timestamp
      final localItem = adapter.createItem(
        id: 'marker-set-1',
        timestamp: DateTime(2024, 2, 1, 12, 0, 1), // T3: client save time
        data: 'new-markers-json',
      );
      // Remote: last successful sync → older timestamp, old payload
      final remoteItem = adapter.createItem(
        id: 'marker-set-1',
        timestamp: DateTime(2024, 2, 1, 12, 0, 0), // T_old
        data: 'old-markers-json',
      );

      adapter.addLocal(localItem, synced: false); // unsynced: user's new data
      adapter.addRemote(remoteItem); // remote: stale

      // Simulate the push always failing (encoding bug, RLS rejection, etc.)
      adapter.failingIds.add('marker-set-1');

      final result = await algorithm.sync();

      expect(result.pushFailures, 1);
      expect(result.pushedUpdates, 0);

      // CRITICAL: local data must NOT be overwritten with old remote data.
      // Pre-fix: adapter.local['marker-set-1']!.item.data would be
      // 'old-markers-json' because the pull phase called upsertLocal(remote).
      expect(adapter.local['marker-set-1']!.item.data, 'new-markers-json');

      // Item stays unsynced so it is retried on the next sync run.
      expect(adapter.local['marker-set-1']!.synced, false);
    });

    test('upsertLocal does not resurrect items with pending soft-deletes',
        () async {
      // Local has unsynced soft-delete
      final localItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 1),
        deleted: true,
      );

      // Remote has newer version (but we don't want to resurrect)
      final remoteItem = adapter.createItem(
        id: 'item1',
        timestamp: DateTime(2024, 1, 2),
        data: 'remote-data',
      );

      adapter.addLocal(localItem, synced: false);
      adapter.addRemote(remoteItem);

      final result = await algorithm.sync();

      // Push delete happens
      expect(result.pushedDeletes, 1);

      // Remote deleted
      expect(adapter.remote.containsKey('item1'), false);

      // Local hard-deleted (not resurrected)
      expect(adapter.local.containsKey('item1'), false);
    });
  });
}
