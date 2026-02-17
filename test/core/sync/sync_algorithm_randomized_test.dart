import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/sync/sync_adapter.dart';
import 'package:repertoire_coach/core/sync/sync_algorithm.dart';

import 'fake_sync_adapter.dart';

void main() {
  group('SyncAlgorithm - randomized property tests', () {
    // Run tests across multiple seeds for thorough coverage
    final seeds = [
      42, 1337, 9999, 12345, 54321, // Hand-picked
      ...List.generate(45, (i) => i * 1000), // 0, 1000, 2000, ..., 44000
    ];

    for (final seed in seeds) {
      test('randomized trial with seed=$seed', () async {
        final random = Random(seed);
        final adapter = FakeSyncAdapter();
        final algorithm = SyncAlgorithm(adapter);

        // Generate random initial state (5-10 operations)
        final numOperations = 5 + random.nextInt(6);
        for (var i = 0; i < numOperations; i++) {
          _applyRandomOperation(random, adapter, i);
        }

        // Optionally inject push failures (20% chance)
        if (random.nextDouble() < 0.2) {
          final failureId = 'item-${random.nextInt(numOperations)}';
          adapter.failingIds.add(failureId);
        }

        // Take snapshot before sync for debugging
        final localBefore = Map.of(adapter.local);
        final remoteBefore = Map.of(adapter.remote);

        // Run sync
        final result = await algorithm.sync();

        // Check invariants
        _checkInvariants(
          adapter,
          result,
          seed,
          localBefore,
          remoteBefore,
        );
      });
    }

    test('idempotency property - double sync gives identical state', () async {
      const numSeeds = 50;

      for (var seed = 0; seed < numSeeds; seed++) {
        final random = Random(seed);
        final adapter = FakeSyncAdapter();
        final algorithm = SyncAlgorithm(adapter);

        // Generate random initial state
        for (var i = 0; i < 10; i++) {
          _applyRandomOperation(random, adapter, i);
        }

        // First sync
        await algorithm.sync();

        // Take snapshot after first sync
        final localAfterFirst = _cloneLocal(adapter.local);
        final remoteAfterFirst = Map.of(adapter.remote);

        // Second sync
        final result2 = await algorithm.sync();

        // Second sync should be no-op
        expect(result2.pushedCreates, 0,
            reason: 'seed=$seed: second sync should not create');
        expect(result2.pushedUpdates, 0,
            reason: 'seed=$seed: second sync should not update');
        expect(result2.pushedDeletes, 0,
            reason: 'seed=$seed: second sync should not delete');
        expect(result2.pulled, 0,
            reason: 'seed=$seed: second sync should not pull');

        // State should be identical
        expect(adapter.local.length, localAfterFirst.length,
            reason: 'seed=$seed: local size changed');
        expect(adapter.remote.length, remoteAfterFirst.length,
            reason: 'seed=$seed: remote size changed');

        for (final id in adapter.local.keys) {
          expect(adapter.local[id]!.item.data, localAfterFirst[id]!.item.data,
              reason: 'seed=$seed: local data changed for $id');
          expect(adapter.local[id]!.synced, localAfterFirst[id]!.synced,
              reason: 'seed=$seed: local synced flag changed for $id');
        }

        for (final id in adapter.remote.keys) {
          expect(adapter.remote[id]!.data, remoteAfterFirst[id]!.data,
              reason: 'seed=$seed: remote data changed for $id');
        }
      }
    });

    test('convergence property - local and remote agree after sync',
        () async {
      const numSeeds = 50;

      for (var seed = 0; seed < numSeeds; seed++) {
        final random = Random(seed);
        final adapter = FakeSyncAdapter();
        final algorithm = SyncAlgorithm(adapter);

        // Generate random initial state with conflicts
        for (var i = 0; i < 10; i++) {
          _applyRandomOperation(random, adapter, i);
        }

        // Run sync
        await algorithm.sync();

        // After sync, every non-deleted item should exist on both sides
        // with matching data (newest version wins)
        for (final localEntry in adapter.local.entries) {
          final id = localEntry.key;
          final localRecord = localEntry.value;

          if (localRecord.item.deleted) {
            // Deleted items should eventually be hard-deleted
            // (but may still exist if unsynced)
            continue;
          }

          if (localRecord.synced) {
            // Synced local items should exist on remote
            expect(adapter.remote.containsKey(id), true,
                reason: 'seed=$seed: synced local item $id missing from remote');

            // Data should match
            expect(adapter.remote[id]!.data, localRecord.item.data,
                reason: 'seed=$seed: data mismatch for $id');
          }
        }

        for (final remoteEntry in adapter.remote.entries) {
          final id = remoteEntry.key;
          final remoteItem = remoteEntry.value;

          // All remote items should exist locally
          expect(adapter.local.containsKey(id), true,
              reason: 'seed=$seed: remote item $id missing from local');

          // Data should match
          expect(adapter.local[id]!.item.data, remoteItem.data,
              reason: 'seed=$seed: data mismatch for $id');
        }
      }
    });
  });
}

/// Applies a random operation to the adapter.
void _applyRandomOperation(Random random, FakeSyncAdapter adapter, int opNum) {
  final id = 'item-${random.nextInt(5)}'; // Reuse IDs to create conflicts
  final timestamp = DateTime(2024, 1, 1 + random.nextInt(10));
  final data = 'data-$opNum';

  // 50% chance to operate on local, 50% on remote
  final isLocal = random.nextBool();

  if (isLocal) {
    // Local operations: create, update, delete
    final opType = random.nextInt(3);

    if (opType == 0) {
      // Create/update local
      final item = adapter.createItem(
        id: id,
        timestamp: timestamp,
        data: data,
      );
      adapter.addLocal(item, synced: false);
    } else if (opType == 1) {
      // Update existing local item
      final existing = adapter.local[id];
      if (existing != null) {
        final updated = existing.item.copyWith(
          syncTimestamp: timestamp,
          data: data,
        );
        adapter.addLocal(updated, synced: false);
      }
    } else {
      // Soft-delete local
      final existing = adapter.local[id];
      if (existing != null) {
        final deleted = existing.item.copyWith(deleted: true);
        adapter.addLocal(deleted, synced: false);
      }
    }
  } else {
    // Remote operations: create, update, delete
    final opType = random.nextInt(3);

    if (opType == 0 || opType == 1) {
      // Create/update remote
      final item = adapter.createItem(
        id: id,
        timestamp: timestamp,
        data: data,
      );
      adapter.addRemote(item);
    } else {
      // Delete remote
      adapter.remote.remove(id);
    }
  }
}

/// Checks sync invariants after running the algorithm.
void _checkInvariants(
  FakeSyncAdapter adapter,
  SyncResult result,
  int seed,
  Map<String, ({FakeItem item, bool synced})> localBefore,
  Map<String, FakeItem> remoteBefore,
) {
  // Invariant 1: Every non-deleted remote item exists in local with matching data
  for (final remoteEntry in adapter.remote.entries) {
    final id = remoteEntry.key;
    final remoteItem = remoteEntry.value;

    expect(adapter.local.containsKey(id), true,
        reason: 'seed=$seed: remote item $id missing from local');

    final localItem = adapter.local[id]!.item;
    expect(localItem.data, remoteItem.data,
        reason: 'seed=$seed: data mismatch for $id');
  }

  // Invariant 2: Every synced non-deleted local item exists in remote
  // (unless push failed)
  for (final localEntry in adapter.local.entries) {
    final id = localEntry.key;
    final localRecord = localEntry.value;

    if (localRecord.synced && !localRecord.item.deleted) {
      // Should exist on remote (unless it was a push failure)
      if (!adapter.failingIds.contains(id)) {
        expect(adapter.remote.containsKey(id), true,
            reason: 'seed=$seed: synced local item $id missing from remote');
      }
    }
  }

  // Invariant 3: No synced+deleted items remain in local
  for (final localEntry in adapter.local.entries) {
    final localRecord = localEntry.value;

    if (localRecord.synced && localRecord.item.deleted) {
      fail('seed=$seed: synced+deleted item ${localEntry.key} was not hard-deleted');
    }
  }

  // Invariant 4: Items with push failures remain unsynced
  for (final failedId in adapter.failingIds) {
    final localRecord = adapter.local[failedId];

    if (localRecord != null && localBefore.containsKey(failedId)) {
      // Item existed before sync and failed to push
      expect(localRecord.synced, false,
          reason: 'seed=$seed: failed item $failedId was marked synced');
    }
  }

  // Invariant 5: Counts make sense
  expect(result.pushedCreates, isNonNegative,
      reason: 'seed=$seed: negative pushedCreates');
  expect(result.pushedUpdates, isNonNegative,
      reason: 'seed=$seed: negative pushedUpdates');
  expect(result.pushedDeletes, isNonNegative,
      reason: 'seed=$seed: negative pushedDeletes');
  expect(result.pulled, isNonNegative, reason: 'seed=$seed: negative pulled');
  expect(result.pushFailures, isNonNegative,
      reason: 'seed=$seed: negative pushFailures');
}

/// Deep clones the local map for comparison.
Map<String, ({FakeItem item, bool synced})> _cloneLocal(
  Map<String, ({FakeItem item, bool synced})> local,
) {
  return Map.fromEntries(
    local.entries.map(
      (e) => MapEntry(
        e.key,
        (
          item: FakeItem(
            syncId: e.value.item.syncId,
            syncTimestamp: e.value.item.syncTimestamp,
            data: e.value.item.data,
            deleted: e.value.item.deleted,
          ),
          synced: e.value.synced,
        ),
      ),
    ),
  );
}
