import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_track_data_source.dart';
import 'package:repertoire_coach/data/models/track_model.dart';
import 'package:repertoire_coach/domain/entities/track.dart' as domain;

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalTrackDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalTrackDataSource(database);
    await dataSource.clearAll();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  final testTrack = TrackModel(
    id: 't1',
    songId: 's1',
    name: 'Test Track',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test('insertTrack and getTrackById', () async {
    await dataSource.insertTrack(testTrack);
    final result = await dataSource.getTrackById('t1');
    expect(result, isA<TrackModel>());
    expect(result?.id, 't1');
  });

  test('getTrackById returns null for non-existent track', () async {
    final result = await dataSource.getTrackById('non-existent');
    expect(result, isNull);
  });

  test('updateTrack updates existing track', () async {
    await dataSource.insertTrack(testTrack);
    final updatedTrack = TrackModel(
      id: 't1',
      songId: 's1',
      name: 'Updated Title',
      createdAt: testTrack.createdAt,
      updatedAt: DateTime.now(),
    );
    final success = await dataSource.updateTrack(updatedTrack);
    final result = await dataSource.getTrackById('t1');
    expect(success, isTrue);
    expect(result?.name, 'Updated Title');
  });

  test('updateTrack returns false for non-existent track', () async {
    final success = await dataSource.updateTrack(testTrack);
    expect(success, isFalse);
  });

  test('upsertTrack inserts a new track', () async {
    await dataSource.upsertTrack(testTrack);
    final result = await dataSource.getTrackById('t1');
    expect(result, isNotNull);
  });

  test('upsertTrack updates an existing track', () async {
    await dataSource.insertTrack(testTrack);
    final updatedTrack = TrackModel(
      id: 't1',
      songId: 's1',
      name: 'Upserted Title',
      createdAt: testTrack.createdAt,
      updatedAt: DateTime.now(),
    );
    await dataSource.upsertTrack(updatedTrack);
    final result = await dataSource.getTrackById('t1');
    expect(result?.name, 'Upserted Title');
  });

  test('deleteTrack soft deletes a track', () async {
    await dataSource.insertTrack(testTrack);
    await dataSource.deleteTrack('t1');
    final result = await dataSource.getTrackById('t1');
    expect(result, isNull);

    // Verify it's in the database but marked as deleted
    final rawTrack = await (database.select(database.tracks)..where((t) => t.id.equals('t1'))).getSingle();
    expect(rawTrack.deleted, isTrue);
  });

  group('watchTracksBySong', () {
    test('emits initial list of tracks', () async {
      final track1 = domain.Track(id: 't1', songId: 's1', name: 'Track 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
      final track2 = domain.Track(id: 't2', songId: 's1', name: 'Track 2', createdAt: DateTime.now(), updatedAt: DateTime.now());
      
      final stream = dataSource.watchTracksBySong('s1');
      
      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<TrackModel>>().having((l) => l.length, 'length', 2)),
      ]));

      await TestDatabaseHelper.seedTracks(database, [track1, track2]);
    });

    test('emits updated list when a track is added', () async {
      final stream = dataSource.watchTracksBySong('s1');

      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<TrackModel>>().having((l) => l.length, 'length', 1)),
      ]));

      await dataSource.insertTrack(testTrack);
    });
  });

  test('getTracksBySong returns correct tracks', () async {
    final track1 = TrackModel(id: 't1', songId: 's1', name: 'Track 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final track2 = TrackModel(id: 't2', songId: 's2', name: 'Track 2', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final track3 = TrackModel(id: 't3', songId: 's1', name: 'Track 3', createdAt: DateTime.now(), updatedAt: DateTime.now());

    await dataSource.insertTrack(track1);
    await dataSource.insertTrack(track2);
    await dataSource.insertTrack(track3);

    final results = await dataSource.getTracksBySong('s1');
    expect(results.length, 2);
    expect(results.any((t) => t.id == 't1'), isTrue);
    expect(results.any((t) => t.id == 't3'), isTrue);
  });

  test('getUnsyncedTracks and markAsSynced', () async {
    await dataSource.insertTrack(testTrack, markForSync: true);

    var unsynced = await dataSource.getUnsyncedTracks();
    expect(unsynced.length, 1);
    expect(unsynced.first.id, 't1');

    await dataSource.markAsSynced('t1');
    unsynced = await dataSource.getUnsyncedTracks();
    expect(unsynced, isEmpty);
  });

  test('clearAll removes all tracks', () async {
    await dataSource.insertTrack(testTrack);
    await dataSource.clearAll();
    final result = await dataSource.getTrackById('t1');
    expect(result, isNull);
  });
}
