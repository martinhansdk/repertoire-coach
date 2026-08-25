import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/errors/marker_invariant_exception.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/models/marker_model.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalMarkerDataSource dataSource;

  final now = DateTime(2024, 1, 1).toUtc();

  final testMarkerSet = MarkerSetModel(
    id: 'ms1',
    trackId: 't1',
    name: 'Verse',
    isShared: false,
    isTimeSynced: true,
    createdByUserId: 'u1',
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalMarkerDataSource(database);
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  // -----------------------------------------------------------------------
  // MarkerSet CRUD
  // -----------------------------------------------------------------------

  group('MarkerSet operations', () {
    test('insertMarkerSet and getMarkerSetById', () async {
      await dataSource.insertMarkerSet(testMarkerSet);
      final result = await dataSource.getMarkerSetById('ms1');
      expect(result, isA<MarkerSetModel>());
      expect(result?.id, 'ms1');
      expect(result?.name, 'Verse');
    });

    test('getMarkerSetById returns null for non-existent id', () async {
      final result = await dataSource.getMarkerSetById('non-existent');
      expect(result, isNull);
    });

    test('getMarkerSetsByTrack returns only sets for that track', () async {
      final other = MarkerSetModel(
        id: 'ms2',
        trackId: 't2',
        name: 'Chorus',
        isShared: false,
        isTimeSynced: true,
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.insertMarkerSet(testMarkerSet);
      await dataSource.insertMarkerSet(other);

      final results = await dataSource.getMarkerSetsByTrack('t1');
      expect(results.length, 1);
      expect(results.first.id, 'ms1');
    });

    test('getMarkerSetsByTrack respects userId filter', () async {
      final sharedSet = MarkerSetModel(
        id: 'ms-shared',
        trackId: 't1',
        name: 'Shared',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'u-other',
        createdAt: now,
        updatedAt: now,
      );
      final privateSet = MarkerSetModel(
        id: 'ms-private',
        trackId: 't1',
        name: 'Private u-other',
        isShared: false,
        isTimeSynced: true,
        createdByUserId: 'u-other',
        createdAt: now,
        updatedAt: now,
      );
      final mySet = testMarkerSet; // owned by u1
      await dataSource.insertMarkerSet(sharedSet);
      await dataSource.insertMarkerSet(privateSet);
      await dataSource.insertMarkerSet(mySet);

      final results = await dataSource.getMarkerSetsByTrack('t1', userId: 'u1');
      // u1 should see: their own set + shared set
      final ids = results.map((s) => s.id).toList();
      expect(ids, containsAll(['ms-shared', 'ms1']));
      expect(ids, isNot(contains('ms-private')));
    });

    test('updateMarkerSet updates name', () async {
      await dataSource.insertMarkerSet(testMarkerSet);
      final updated = MarkerSetModel(
        id: 'ms1',
        trackId: 't1',
        name: 'Bridge',
        isShared: false,
        isTimeSynced: true,
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: DateTime.now().toUtc(),
      );
      final success = await dataSource.updateMarkerSet(updated);
      expect(success, isTrue);
      final result = await dataSource.getMarkerSetById('ms1');
      expect(result?.name, 'Bridge');
    });

    test('updateMarkerSet returns false for non-existent id', () async {
      final success = await dataSource.updateMarkerSet(testMarkerSet);
      expect(success, isFalse);
    });

    test('upsertMarkerSet inserts if not present', () async {
      await dataSource.upsertMarkerSet(testMarkerSet);
      final result = await dataSource.getMarkerSetById('ms1');
      expect(result, isNotNull);
    });

    test('upsertMarkerSet updates if already present', () async {
      await dataSource.insertMarkerSet(testMarkerSet);
      final updated = MarkerSetModel(
        id: 'ms1',
        trackId: 't1',
        name: 'Updated Name',
        isShared: false,
        isTimeSynced: true,
        createdByUserId: 'u1',
        createdAt: now,
        updatedAt: DateTime.now().toUtc(),
      );
      await dataSource.upsertMarkerSet(updated);
      final result = await dataSource.getMarkerSetById('ms1');
      expect(result?.name, 'Updated Name');
    });

    test('deleteMarkerSet soft-deletes and hides from queries', () async {
      await dataSource.insertMarkerSet(testMarkerSet);
      await dataSource.deleteMarkerSet('ms1');

      // Logical queries exclude deleted records
      final result = await dataSource.getMarkerSetById('ms1');
      expect(result, isNull);

      // Raw row still exists with deleted=true
      final raw = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      expect(raw.deleted, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // MarkerSet sync operations
  // -----------------------------------------------------------------------

  group('MarkerSet sync operations', () {
    test('getUnsyncedMarkerSets returns sets with synced=false', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: true);

      final unsynced = await dataSource.getUnsyncedMarkerSets();
      expect(unsynced.length, 1);
      expect(unsynced.first.id, 'ms1');
    });

    test('markMarkerSetAsSynced clears unsynced flag', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: true);
      await dataSource.markMarkerSetAsSynced('ms1', testMarkerSet.updatedAt);

      final unsynced = await dataSource.getUnsyncedMarkerSets();
      expect(unsynced, isEmpty);
    });

    test('hardDeleteSyncedDeletedMarkerSets removes synced+deleted rows', () async {
      await dataSource.insertMarkerSet(testMarkerSet);
      await dataSource.deleteMarkerSet('ms1');
      // The soft-delete stamped a fresh deletion time; conditional markSynced
      // needs the row's current updatedAt.
      final deletedRow = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      await dataSource.markMarkerSetAsSynced('ms1', deletedRow.updatedAt);

      await dataSource.hardDeleteSyncedDeletedMarkerSets();

      final raw = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingleOrNull();
      expect(raw, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Marker (JSON payload) operations
  // -----------------------------------------------------------------------

  group('Marker operations', () {
    setUp(() async {
      await dataSource.insertMarkerSet(testMarkerSet);
    });

    test('getMarkersByMarkerSet returns empty list for new set', () async {
      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers, isEmpty);
    });

    test('upsertMarker adds a marker to an empty set', () async {
      final marker = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Intro',
        positionMs: 1000,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(marker);

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers.length, 1);
      expect(markers.first.label, 'Intro');
      expect(markers.first.positionMs, 1000);
    });

    test('upsertMarker appends at a higher index', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Start',
        positionMs: 0,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      final m1 = MarkerModel(
        id: 'ms1:1',
        markerSetId: 'ms1',
        label: 'Middle',
        positionMs: 5000,
        order: 1,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);
      await dataSource.upsertMarker(m1);

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers.length, 2);
      expect(markers[0].positionMs, 0);
      expect(markers[1].positionMs, 5000);
    });

    test('upsertMarker updates label and position at existing index', () async {
      final original = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Old',
        positionMs: 100,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(original);

      final updated = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'New',
        positionMs: 200,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(updated);

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers.length, 1);
      expect(markers.first.label, 'New');
      expect(markers.first.positionMs, 200);
    });

    test('deleteMarker removes marker at index and shifts remaining', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'First',
        positionMs: 0,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      final m1 = MarkerModel(
        id: 'ms1:1',
        markerSetId: 'ms1',
        label: 'Second',
        positionMs: 3000,
        order: 1,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);
      await dataSource.upsertMarker(m1);

      await dataSource.deleteMarker('ms1:0');

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers.length, 1);
      expect(markers.first.label, 'Second');
    });

    test('deleteMarker is a no-op for invalid synthetic id', () async {
      await dataSource.deleteMarker('invalid');
      // No exception; nothing changed
      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers, isEmpty);
    });

    test('replaceMarkersByMarkerSet replaces all markers', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Old',
        positionMs: 1000,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);

      final replacement = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Replaced',
        positionMs: 500,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.replaceMarkersByMarkerSet('ms1', [replacement]);

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers.length, 1);
      expect(markers.first.label, 'Replaced');
    });

    test('deleteMarkersByMarkerSet clears all markers', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'A',
        positionMs: 0,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);

      await dataSource.deleteMarkersByMarkerSet('ms1');

      final markers = await dataSource.getMarkersByMarkerSet('ms1');
      expect(markers, isEmpty);
    });

    test('upsertMarker throws on non-monotonic positions', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Late',
        positionMs: 5000,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      final m1 = MarkerModel(
        id: 'ms1:1',
        markerSetId: 'ms1',
        label: 'Early',
        positionMs: 1000, // earlier than m0 → invariant violation
        order: 1,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);

      expect(
        () => dataSource.upsertMarker(m1),
        throwsA(isA<MarkerInvariantException>()),
      );
    });

    test('getMarkerById returns correct marker', () async {
      final m0 = MarkerModel(
        id: 'ms1:0',
        markerSetId: 'ms1',
        label: 'Target',
        positionMs: 2000,
        order: 0,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertMarker(m0);

      final result = await dataSource.getMarkerById('ms1:0');
      expect(result?.label, 'Target');
    });

    test('getMarkerById returns null for invalid id', () async {
      final result = await dataSource.getMarkerById('invalid');
      expect(result, isNull);
    });

    test('getMarkerById returns null for out-of-range index', () async {
      final result = await dataSource.getMarkerById('ms1:99');
      expect(result, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Watch stream
  // -----------------------------------------------------------------------

  group('watchMarkerSetsByTrack', () {
    test('emits the current list of marker sets', () async {
      await dataSource.insertMarkerSet(testMarkerSet);

      final results = await dataSource.watchMarkerSetsByTrack('t1').first;
      expect(results.length, 1);
      expect(results.first.id, 'ms1');
    });

    test('emits empty list when no sets exist for the track', () async {
      final results = await dataSource.watchMarkerSetsByTrack('t1').first;
      expect(results, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Sync regressions (tombstone/conditional semantics, migration 013)
  //
  // These exercise the real Drift SQL behind the failure modes where changes
  // vanished from the device that made them or never reached other devices.
  // -----------------------------------------------------------------------

  group('Sync regressions', () {
    MarkerSetModel variantOf(
      MarkerSetModel base, {
      required DateTime updatedAt,
      String? name,
      bool deleted = false,
    }) {
      return MarkerSetModel(
        id: base.id,
        trackId: base.trackId,
        name: name ?? base.name,
        isShared: base.isShared,
        isTimeSynced: base.isTimeSynced,
        createdByUserId: base.createdByUserId,
        createdAt: base.createdAt,
        updatedAt: updatedAt,
        markersJson: base.markersJson,
        deleted: deleted,
      );
    }

    test(
        'REGRESSION: conditional markSynced — a row edited after the sync '
        'snapshot must stay unsynced', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: true);

      // The user edits the set while the sync run (which snapshotted
      // updatedAt == now) has its push in flight.
      final edited = variantOf(testMarkerSet,
          updatedAt: now.add(const Duration(minutes: 5)), name: 'Chorus');
      await dataSource.upsertMarkerSet(edited, markForSync: true);

      // Sync tries to mark synced with the STALE snapshot timestamp.
      await dataSource.markMarkerSetAsSynced('ms1', testMarkerSet.updatedAt);

      final unsynced = await dataSource.getUnsyncedMarkerSets();
      expect(unsynced.length, 1,
          reason: 'the mid-sync edit must remain unsynced so the next run '
              'pushes it; the old unconditional markSynced silently dropped '
              'such edits and they never reached other devices');
      expect(unsynced.first.name, 'Chorus');
    });

    test(
        'REGRESSION: pull upsert must not overwrite a newer unsynced local '
        'change', () async {
      final localEdit = variantOf(testMarkerSet,
          updatedAt: now.add(const Duration(minutes: 10)), name: 'Local edit');
      await dataSource.insertMarkerSet(localEdit, markForSync: true);

      // A pull arrives carrying an OLDER remote version.
      final staleRemote =
          variantOf(testMarkerSet, updatedAt: now, name: 'Stale remote');
      await dataSource.upsertMarkerSet(staleRemote, markForSync: false);

      final row = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      expect(row.name, 'Local edit',
          reason: 'the newer unsynced local change wins locally');
      expect(row.synced, false,
          reason: 'it stays unsynced and is pushed on the next run');
    });

    test(
        'REGRESSION: pull upsert applies a newer remote version over an '
        'older synced row', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: false);

      final newerRemote = variantOf(testMarkerSet,
          updatedAt: now.add(const Duration(minutes: 5)),
          name: 'Remote newer');
      await dataSource.upsertMarkerSet(newerRemote, markForSync: false);

      final row = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      expect(row.name, 'Remote newer');
      expect(row.synced, true);
    });

    test(
        'REGRESSION: a pulled tombstone lands as synced+deleted and is then '
        'purged — deletion syncs as data, not absence', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: false);

      final tombstone = variantOf(testMarkerSet,
          updatedAt: now.add(const Duration(minutes: 5)), deleted: true);
      await dataSource.upsertMarkerSet(tombstone, markForSync: false);

      final row = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      expect(row.deleted, true);
      expect(row.synced, true);

      await dataSource.hardDeleteSyncedDeletedMarkerSets();

      final purged = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingleOrNull();
      expect(purged, isNull);
    });

    test(
        'REGRESSION: a locally soft-deleted row is NOT resurrected by an '
        'older pulled version', () async {
      await dataSource.insertMarkerSet(testMarkerSet, markForSync: false);
      await dataSource.deleteMarkerSet('ms1'); // stamps a fresh deletion time

      final staleRemote =
          variantOf(testMarkerSet, updatedAt: now, name: 'Stale remote');
      await dataSource.upsertMarkerSet(staleRemote, markForSync: false);

      final row = await (database.select(database.markerSets)
            ..where((ms) => ms.id.equals('ms1')))
          .getSingle();
      expect(row.deleted, true,
          reason: 'the newer local deletion wins until the push resolves it');
      expect(row.synced, false);
    });
  });

}
