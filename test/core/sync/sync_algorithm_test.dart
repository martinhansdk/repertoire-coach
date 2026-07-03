import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/sync/sync_algorithm.dart';

import 'fake_sync_adapter.dart';

void main() {
  group('SyncAlgorithm - basic scenarios', () {
    late FakeSyncAdapter adapter;
    late SyncAlgorithm<FakeItem> algorithm;

    setUp(() {
      adapter = FakeSyncAdapter();
      algorithm = SyncAlgorithm(adapter);
    });

    test('both sides empty -> no-op', () async {
      final result = await algorithm.sync();

      expect(result.pushedCreates, 0);
      expect(result.pushedUpdates, 0);
      expect(result.pushedDeletes, 0);
      expect(result.pulled, 0);
      expect(result.pushFailures, 0);
      expect(adapter.local, isEmpty);
      expect(adapter.remote, isEmpty);
    });

    test('local only -> push all', () async {
      adapter.addLocal(adapter.createItem(id: 'a'), synced: false);
      adapter.addLocal(adapter.createItem(id: 'b'), synced: false);

      final result = await algorithm.sync();

      expect(result.pushedCreates, 2);
      expect(adapter.remote.length, 2);
      expect(adapter.local['a']!.synced, true);
      expect(adapter.local['b']!.synced, true);
    });

    test('remote only -> pull all', () async {
      adapter.addRemote(adapter.createItem(id: 'a'));
      adapter.addRemote(adapter.createItem(id: 'b'));

      final result = await algorithm.sync();

      expect(result.pulled, 2);
      expect(adapter.local.length, 2);
      expect(adapter.local['a']!.synced, true);
    });

    test('newer local edit wins over older remote', () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'old', timestamp: DateTime(2024, 1, 1)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'new', timestamp: DateTime(2024, 1, 2)),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pushedUpdates, 1);
      expect(adapter.remote['a']!.data, 'new');
      expect(adapter.local['a']!.item.data, 'new');
      expect(adapter.local['a']!.synced, true);
    });

    test('newer remote edit wins over older unsynced local', () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'new', timestamp: DateTime(2024, 1, 2)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'old', timestamp: DateTime(2024, 1, 1)),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pulled, 1);
      expect(adapter.local['a']!.item.data, 'new');
      expect(adapter.local['a']!.synced, true);
      // Remote keeps its version; the stale local edit was NOT pushed.
      expect(adapter.remote['a']!.data, 'new');
    });

    test('push failure isolates the item and leaves it unsynced', () async {
      adapter.addLocal(adapter.createItem(id: 'bad'), synced: false);
      adapter.addLocal(adapter.createItem(id: 'good'), synced: false);
      adapter.failingIds.add('bad');

      final result = await algorithm.sync();

      expect(result.pushFailures, 1);
      expect(result.pushedCreates, 1);
      expect(adapter.local['bad']!.synced, false, reason: 'retried next run');
      expect(adapter.local['good']!.synced, true);
      expect(adapter.remote.containsKey('bad'), false);
    });
  });

  // Each test below reproduces a real data-loss or data-stuck failure mode
  // found in the field ("changes not reaching other devices" / "changes
  // disappearing from the device that made them"). They fail against the
  // pre-013 sync design.
  group('SyncAlgorithm - regressions', () {
    late FakeSyncAdapter adapter;
    late SyncAlgorithm<FakeItem> algorithm;

    setUp(() {
      adapter = FakeSyncAdapter();
      algorithm = SyncAlgorithm(adapter);
    });

    test(
        'REGRESSION: empty/partial remote read must not delete local data '
        '(deletion is never inferred from absence)', () async {
      // Old behavior: hardDeleteSyncedNotIn(remoteIds) wiped every synced
      // local row when getAllRemote() came back empty or truncated.
      adapter.addLocal(
          adapter.createItem(id: 'a', data: 'precious'), synced: true);
      adapter.addLocal(
          adapter.createItem(id: 'b', data: 'also precious'), synced: true);
      adapter.remoteReadReturnsEmpty = true;

      await algorithm.sync();

      expect(adapter.local.length, 2,
          reason: 'an empty remote read means "no information", not '
              '"everything was deleted remotely"');
      expect(adapter.local['a']!.item.data, 'precious');
    });

    test('REGRESSION: deletion propagates as a tombstone row', () async {
      // Device A: soft-deletes a synced item and syncs.
      final deletedAt = DateTime(2024, 2, 1);
      adapter.addRemote(adapter.createItem(id: 'a'));
      adapter.addLocal(
          adapter.createItem(id: 'a', timestamp: deletedAt, deleted: true),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 1);
      // Remote row still exists — as a tombstone stamped with deletion time.
      expect(adapter.remote['a'], isNotNull);
      expect(adapter.remote['a']!.deleted, true);
      expect(adapter.remote['a']!.syncTimestamp, deletedAt);
      // Locally the fully-applied tombstone is purged.
      expect(adapter.local.containsKey('a'), false);

      // Device B: had the item synced; pulling applies the tombstone.
      final deviceB = FakeSyncAdapter()..remote.addAll(adapter.remote);
      deviceB.addLocal(deviceB.createItem(id: 'a'), synced: true);

      await SyncAlgorithm<FakeItem>(deviceB).sync();

      expect(deviceB.local.containsKey('a'), false,
          reason: 'tombstone pulled and purged on the other device');
    });

    test('REGRESSION: newer remote tombstone beats older local edit',
        () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', deleted: true, timestamp: DateTime(2024, 1, 5)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'stale edit', timestamp: DateTime(2024, 1, 2)),
          synced: false);

      await algorithm.sync();

      expect(adapter.local.containsKey('a'), false,
          reason: 'deletion was newer, so it wins and the row is purged');
      expect(adapter.remote['a']!.deleted, true);
    });

    test(
        'REGRESSION: newer local edit deliberately resurrects an older '
        'remote tombstone (newest wins, uniformly)', () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', deleted: true, timestamp: DateTime(2024, 1, 2)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'newer edit', timestamp: DateTime(2024, 1, 5)),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pushedUpdates, 1);
      expect(adapter.remote['a']!.deleted, false);
      expect(adapter.remote['a']!.data, 'newer edit');
      expect(adapter.local['a']!.synced, true);
    });

    test(
        'REGRESSION: newer local deletion beats older remote edit '
        '(delete no longer wins unconditionally — but it wins here on time)',
        () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'older edit', timestamp: DateTime(2024, 1, 2)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', deleted: true, timestamp: DateTime(2024, 1, 5)),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 1);
      expect(adapter.remote['a']!.deleted, true);
      expect(adapter.local.containsKey('a'), false);
    });

    test(
        'REGRESSION: older local deletion loses to newer remote edit '
        '(offline delete cannot destroy fresher work)', () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'fresh work', timestamp: DateTime(2024, 1, 5)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', deleted: true, timestamp: DateTime(2024, 1, 2)),
          synced: false);

      final result = await algorithm.sync();

      expect(result.pushedDeletes, 0);
      expect(adapter.remote['a']!.deleted, false,
          reason: 'the stale deletion must not be pushed');
      expect(adapter.local['a']!.item.data, 'fresh work');
      expect(adapter.local['a']!.item.deleted, false);
    });

    test(
        'REGRESSION: user edit landing mid-sync is not silently marked '
        'synced (conditional markSynced)', () async {
      // Old behavior: markSynced(id) was unconditional, so an edit made
      // between the unsynced snapshot and markSynced was flagged as synced
      // without ever being pushed — it never reached other devices.
      final t0 = DateTime(2024, 1, 1);
      final tEdit = DateTime(2024, 1, 2);
      adapter.addLocal(
          adapter.createItem(id: 'a', data: 'v1', timestamp: t0),
          synced: false);

      adapter.onBeforeMarkSynced = (id) {
        // Simulate the user editing the item while the push is in flight.
        adapter.local[id] = (
          item: adapter.createItem(id: id, data: 'v2', timestamp: tEdit),
          synced: false,
        );
      };

      await algorithm.sync();

      expect(adapter.local['a']!.synced, false,
          reason: 'the mid-sync edit must stay unsynced');
      expect(adapter.local['a']!.item.data, 'v2');

      // The next run pushes the edit.
      adapter.onBeforeMarkSynced = null;
      await SyncAlgorithm<FakeItem>(adapter).sync();
      expect(adapter.remote['a']!.data, 'v2');
      expect(adapter.local['a']!.synced, true);
    });

    test(
        'REGRESSION: user edit landing mid-sync is not overwritten by the '
        'pull upsert (timestamp guard in upsertLocal)', () async {
      // Remote is newer than the snapshotted local row, so the algorithm
      // decides to pull — but the user edits again before the upsert lands.
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'remote', timestamp: DateTime(2024, 1, 3)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'v1', timestamp: DateTime(2024, 1, 1)),
          synced: false);

      adapter.onBeforeUpsertLocal = (incoming) {
        adapter.local['a'] = (
          item: adapter.createItem(
              id: 'a', data: 'v2-newest', timestamp: DateTime(2024, 1, 5)),
          synced: false,
        );
      };

      await algorithm.sync();

      expect(adapter.local['a']!.item.data, 'v2-newest',
          reason: 'the newest local edit survives and stays unsynced');
      expect(adapter.local['a']!.synced, false);
    });

    test(
        'REGRESSION: two devices converge on the newest edit '
        '(edit-time, not push-time, decides conflicts)', () async {
      // Old behavior: the remote row was stamped with push time, so a device
      // pushing an OLDER edit LATER won conflicts, and the device holding the
      // genuinely newer edit watched its own change get overwritten.
      final shared = <String, FakeItem>{};

      final deviceA = FakeSyncAdapter();
      final deviceB = FakeSyncAdapter();

      // Both devices start with the same synced item.
      final base = deviceA.createItem(
          id: 'a', data: 'base', timestamp: DateTime(2024, 1, 1));
      for (final d in [deviceA, deviceB]) {
        d.addLocal(base, synced: true);
      }
      shared[base.syncId] = base;

      // B edits at 14:05 (offline). A edits EARLIER, at 14:00, but pushes
      // FIRST, at 14:10.
      deviceB.addLocal(
          deviceB.createItem(
              id: 'a', data: 'B-newer', timestamp: DateTime(2024, 1, 2, 14, 5)),
          synced: false);
      deviceA.addLocal(
          deviceA.createItem(
              id: 'a', data: 'A-older', timestamp: DateTime(2024, 1, 2, 14, 0)),
          synced: false);

      Future<void> syncDevice(FakeSyncAdapter d) async {
        d.remote
          ..clear()
          ..addAll(shared);
        await SyncAlgorithm<FakeItem>(d).sync();
        shared
          ..clear()
          ..addAll(d.remote);
      }

      await syncDevice(deviceA); // A pushes its older edit first
      await syncDevice(deviceB); // B syncs after
      await syncDevice(deviceA); // A syncs again

      expect(shared['a']!.data, 'B-newer');
      expect(deviceA.local['a']!.item.data, 'B-newer',
          reason: 'A converges to the newest edit');
      expect(deviceB.local['a']!.item.data, 'B-newer',
          reason: "B's newer edit must never be overwritten by A's older one");
    });

    test('REGRESSION: tombstone for a never-seen item is not pulled',
        () async {
      adapter.addRemote(adapter.createItem(id: 'ghost', deleted: true));

      final result = await algorithm.sync();

      expect(result.pulled, 0);
      expect(adapter.local, isEmpty,
          reason: 'no point materializing a deletion we never knew about');
    });

    test(
        'REGRESSION: failed push keeps the item out of the pull phase '
        '(remote must not overwrite a change we could not upload)', () async {
      adapter.addRemote(adapter.createItem(
          id: 'a', data: 'remote', timestamp: DateTime(2024, 1, 3)));
      adapter.addLocal(
          adapter.createItem(
              id: 'a', data: 'local-newer', timestamp: DateTime(2024, 1, 5)),
          synced: false);
      adapter.failingIds.add('a');

      final result = await algorithm.sync();

      expect(result.pushFailures, 1);
      expect(adapter.local['a']!.item.data, 'local-newer');
      expect(adapter.local['a']!.synced, false, reason: 'retried next run');
    });
  });
}
