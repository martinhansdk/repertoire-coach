import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/data/models/song_model.dart';
import 'package:repertoire_coach/domain/entities/song.dart' as domain;

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalSongDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalSongDataSource(database);
    await dataSource.clearAll();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  final testSong = SongModel(
    id: 's1',
    concertId: 'c1',
    title: 'Test Song',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test('insertSong and getSongById', () async {
    await dataSource.insertSong(testSong);
    final result = await dataSource.getSongById('s1');
    expect(result, isA<SongModel>());
    expect(result?.id, 's1');
  });

  test('getSongById returns null for non-existent song', () async {
    final result = await dataSource.getSongById('non-existent');
    expect(result, isNull);
  });

  test('updateSong updates existing song', () async {
    await dataSource.insertSong(testSong);
    final updatedSong = SongModel(
      id: 's1',
      concertId: 'c1',
      title: 'Updated Title',
      createdAt: testSong.createdAt,
      updatedAt: DateTime.now(),
    );
    final success = await dataSource.updateSong(updatedSong);
    final result = await dataSource.getSongById('s1');
    expect(success, isTrue);
    expect(result?.title, 'Updated Title');
  });

  test('updateSong returns false for non-existent song', () async {
    final success = await dataSource.updateSong(testSong);
    expect(success, isFalse);
  });

  test('upsertSong inserts a new song', () async {
    await dataSource.upsertSong(testSong);
    final result = await dataSource.getSongById('s1');
    expect(result, isNotNull);
  });

  test('upsertSong updates an existing song', () async {
    await dataSource.insertSong(testSong);
    final updatedSong = SongModel(
      id: 's1',
      concertId: 'c1',
      title: 'Upserted Title',
      createdAt: testSong.createdAt,
      updatedAt: DateTime.now(),
    );
    await dataSource.upsertSong(updatedSong);
    final result = await dataSource.getSongById('s1');
    expect(result?.title, 'Upserted Title');
  });

  test('deleteSong soft deletes a song', () async {
    await dataSource.insertSong(testSong);
    await dataSource.deleteSong('s1');
    final result = await dataSource.getSongById('s1');
    expect(result, isNull);

    // Verify it's in the database but marked as deleted
    final rawSong = await (database.select(database.songs)..where((s) => s.id.equals('s1'))).getSingle();
    expect(rawSong.deleted, isTrue);
  });

  group('watchSongsByConcert', () {
    test('emits initial list of songs', () async {
      final song1 = domain.Song(id: 's1', concertId: 'c1', title: 'Song 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
      final song2 = domain.Song(id: 's2', concertId: 'c1', title: 'Song 2', createdAt: DateTime.now(), updatedAt: DateTime.now());
      
      final stream = dataSource.watchSongsByConcert('c1');
      
      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<SongModel>>().having((l) => l.length, 'length', 2)),
      ]));

      await TestDatabaseHelper.seedSongs(database, [song1, song2]);
    });

    test('emits updated list when a song is added', () async {
      final stream = dataSource.watchSongsByConcert('c1');

      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<SongModel>>().having((l) => l.length, 'length', 1)),
      ]));

      await dataSource.insertSong(testSong);
    });
  });

  test('getSongsByConcert returns correct songs', () async {
    final song1 = SongModel(id: 's1', concertId: 'c1', title: 'Song 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final song2 = SongModel(id: 's2', concertId: 'c2', title: 'Song 2', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final song3 = SongModel(id: 's3', concertId: 'c1', title: 'Song 3', createdAt: DateTime.now(), updatedAt: DateTime.now());

    await dataSource.insertSong(song1);
    await dataSource.insertSong(song2);
    await dataSource.insertSong(song3);

    final results = await dataSource.getSongsByConcert('c1');
    expect(results.length, 2);
    expect(results.any((s) => s.id == 's1'), isTrue);
    expect(results.any((s) => s.id == 's3'), isTrue);
  });

  test('getUnsyncedSongs and markAsSynced', () async {
    await dataSource.insertSong(testSong, markForSync: true);

    var unsynced = await dataSource.getUnsyncedSongs();
    expect(unsynced.length, 1);
    expect(unsynced.first.id, 's1');

    await dataSource.markAsSynced('s1');
    unsynced = await dataSource.getUnsyncedSongs();
    expect(unsynced, isEmpty);
  });

  test('clearAll removes all songs', () async {
    await dataSource.insertSong(testSong);
    await dataSource.clearAll();
    final result = await dataSource.getSongById('s1');
    expect(result, isNull);
  });
}
