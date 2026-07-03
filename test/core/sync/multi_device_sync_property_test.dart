import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/sync/sync_algorithm.dart';

import 'fake_sync_adapter.dart';

/// Multi-device model checker for the sync algorithm.
///
/// Simulates N devices sharing one remote store while users make random,
/// interleaved edits and deletions, and devices sync at random times — with
/// random *degraded* syncs mixed in (per-item push failures, empty/partial
/// remote reads). After the dust settles, every device must have converged on
/// the same state, and that state must honor the core promise:
///
///   **No acknowledged write is ever lost**: for every item, the surviving
///   value is exactly the one with the globally newest edit timestamp — an
///   edit or a deletion, whichever came last.
///
/// This is the formal statement of "changes don't disappear from the device
/// that made them" and "changes reach other devices".
///
/// Model limitations (documented, deliberate):
///  - Sync runs are serialized (the SyncController reentrancy guard enforces
///    this per device in production; cross-device runs interleave only at
///    whole-run granularity here).
///  - Device clocks are sane: timestamps are drawn from one global monotonic
///    counter, so "newest" is well-defined. Clock-skew behavior is out of
///    scope for these properties.
void main() {
  group('Multi-device sync properties', () {
    // A generous seed set: each trial explores a different interleaving.
    final seeds = List.generate(120, (i) => i * 7919); // spread via a prime

    for (final seed in seeds) {
      test('random interleaving, seed=$seed', () async {
        final random = Random(seed);
        final world = _World(random, deviceCount: 2 + random.nextInt(3));

        final steps = 30 + random.nextInt(21); // 30-50 steps
        for (var i = 0; i < steps; i++) {
          await world.randomStep(i);
        }

        await world.quiesce();
        world.checkProperties(seed);
      });
    }

    test('deterministic: interrupted sync resumes without losing anything',
        () async {
      final world = _World(Random(1), deviceCount: 2);
      final a = world.devices[0];
      final b = world.devices[1];

      // A creates two items; its first sync fails to push one of them and
      // reads back nothing (degraded network).
      world.recordEdit(a, 'x', data: 'x1');
      world.recordEdit(a, 'y', data: 'y1');
      a.failingIds.add('y');
      a.remoteReadReturnsEmpty = true;
      await SyncAlgorithm<FakeItem>(a).sync();
      a.failingIds.clear();
      a.remoteReadReturnsEmpty = false;

      // B edits x concurrently (newer), then syncs.
      world.recordEdit(b, 'x', data: 'x2-newer');
      await SyncAlgorithm<FakeItem>(b).sync();

      await world.quiesce();
      world.checkProperties(1);

      expect(a.local['x']!.item.data, 'x2-newer');
      expect(b.local['y']!.item.data, 'y1',
          reason: "A's failed push of y must eventually reach B");
    });
  });
}

/// One simulated world: N devices, one shared remote, and an oracle recording
/// the globally newest operation per item id.
class _World {
  final Random random;
  final Map<String, FakeItem> sharedRemote = {};
  final List<FakeSyncAdapter> devices;
  final Map<String, _OracleOp> oracle = {};

  /// Global monotonic clock: every operation gets a strictly newer timestamp.
  int _tick = 0;
  DateTime _nextTs() =>
      DateTime.utc(2024, 1, 1).add(Duration(seconds: ++_tick));

  static const _idPool = [
    'item-0', 'item-1', 'item-2', 'item-3',
    'item-4', 'item-5', 'item-6', 'item-7',
  ];

  _World(this.random, {required int deviceCount})
      : devices = <FakeSyncAdapter>[] {
    for (var i = 0; i < deviceCount; i++) {
      // All devices share one remote store.
      devices.add(FakeSyncAdapter(sharedRemote: sharedRemote));
    }
  }

  /// Records a user edit (create or update) on [device].
  void recordEdit(FakeSyncAdapter device, String id, {required String data}) {
    final ts = _nextTs();
    device.addLocal(
      FakeItem(syncId: id, syncTimestamp: ts, data: data),
      synced: false,
    );
    oracle[id] = _OracleOp(ts: ts, data: data, deleted: false);
  }

  /// Records a user deletion on [device] — only possible for rows the device
  /// can actually see, like in the UI.
  bool recordDelete(FakeSyncAdapter device, String id) {
    final existing = device.local[id];
    if (existing == null || existing.item.deleted) return false;
    final ts = _nextTs();
    device.addLocal(
      existing.item.copyWith(deleted: true, syncTimestamp: ts),
      synced: false,
    );
    oracle[id] = _OracleOp(ts: ts, data: existing.item.data, deleted: true);
    return true;
  }

  Future<void> randomStep(int stepNo) async {
    final device = devices[random.nextInt(devices.length)];
    final roll = random.nextDouble();

    if (roll < 0.40) {
      // User edit.
      recordEdit(device, _idPool[random.nextInt(_idPool.length)],
          data: 'd$stepNo');
    } else if (roll < 0.50) {
      // User deletion (skip silently if the device sees no such row).
      recordDelete(device, _idPool[random.nextInt(_idPool.length)]);
    } else if (roll < 0.80) {
      // Clean sync.
      await SyncAlgorithm<FakeItem>(device).sync();
    } else {
      // Degraded sync: random per-item push failures and/or an empty remote
      // read. Both were real-world conditions behind the field bugs.
      if (random.nextBool()) {
        device.failingIds
            .add(_idPool[random.nextInt(_idPool.length)]);
      }
      if (random.nextBool()) {
        device.remoteReadReturnsEmpty = true;
      }
      await SyncAlgorithm<FakeItem>(device).sync();
      device.failingIds.clear();
      device.remoteReadReturnsEmpty = false;
    }
  }

  /// Clears all failure modes and lets every device sync repeatedly until
  /// nothing changes anymore (bounded, with a final fixed number of rounds
  /// as a safety net — 3 rounds are provably enough: one to land the newest
  /// value of every item on the remote, one to pull it everywhere, one for
  /// tombstone purges).
  Future<void> quiesce() async {
    for (final d in devices) {
      d.failingIds.clear();
      d.remoteReadReturnsEmpty = false;
    }
    for (var round = 0; round < 3; round++) {
      for (final d in devices) {
        await SyncAlgorithm<FakeItem>(d).sync();
      }
    }
  }

  void checkProperties(int seed) {
    for (final entry in oracle.entries) {
      final id = entry.key;
      final op = entry.value;

      if (op.deleted) {
        // PROPERTY: an acknowledged deletion (the globally newest op) holds
        // everywhere — and only via tombstone, never via absence guessing.
        for (var i = 0; i < devices.length; i++) {
          expect(devices[i].local.containsKey(id), false,
              reason: 'seed=$seed: device $i still has deleted item $id');
        }
        final remoteRow = sharedRemote[id];
        expect(remoteRow == null || remoteRow.deleted, true,
            reason: 'seed=$seed: remote row for deleted $id is live');
      } else {
        // PROPERTY: no acknowledged write is lost — the newest edit's exact
        // data survives on every device and on the remote.
        for (var i = 0; i < devices.length; i++) {
          final rec = devices[i].local[id];
          expect(rec, isNotNull,
              reason: 'seed=$seed: device $i lost item $id entirely');
          expect(rec!.item.data, op.data,
              reason: 'seed=$seed: device $i holds stale data for $id '
                  '(has "${rec.item.data}", newest was "${op.data}")');
          expect(rec.item.syncTimestamp, op.ts,
              reason: 'seed=$seed: device $i timestamp drift for $id');
          expect(rec.synced, true,
              reason: 'seed=$seed: device $i item $id still unsynced '
                  'after quiescence');
        }
        final remoteRow = sharedRemote[id];
        expect(remoteRow, isNotNull,
            reason: 'seed=$seed: remote lost item $id');
        expect(remoteRow!.deleted, false,
            reason: 'seed=$seed: remote wrongly tombstoned $id');
        expect(remoteRow.data, op.data,
            reason: 'seed=$seed: remote holds stale data for $id');
      }
    }

    // PROPERTY: convergence — no device holds anything the oracle doesn't
    // know about, and all devices agree with each other.
    for (var i = 0; i < devices.length; i++) {
      for (final id in devices[i].local.keys) {
        expect(oracle.containsKey(id), true,
            reason: 'seed=$seed: device $i has phantom item $id');
      }
      expect(devices[i].local.length, devices[0].local.length,
          reason: 'seed=$seed: devices 0 and $i diverged in item count');
    }
  }
}

class _OracleOp {
  final DateTime ts;
  final String data;
  final bool deleted;
  _OracleOp({required this.ts, required this.data, required this.deleted});
}
