import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/domain/entities/concert.dart' as domain;

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalConcertDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalConcertDataSource(database);
    await dataSource.clearAll();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  final testConcert = ConcertModel(
    id: 'c1',
    choirId: 'choir1',
    choirName: 'Test Choir',
    name: 'Test Concert',
    concertDate: DateTime.now(),
    createdAt: DateTime.now(),
  );

  test('insertConcert and getConcertById', () async {
    await dataSource.insertConcert(testConcert);
    final result = await dataSource.getConcertById('c1');
    expect(result, isA<ConcertModel>());
    expect(result?.id, 'c1');
  });

  test('getConcertById returns null for non-existent concert', () async {
    final result = await dataSource.getConcertById('non-existent');
    expect(result, isNull);
  });

  test('updateConcert updates existing concert', () async {
    await dataSource.insertConcert(testConcert);
    final updatedConcert = ConcertModel(
      id: 'c1',
      choirId: 'choir1',
      choirName: 'Test Choir',
      name: 'Updated Title',
      concertDate: testConcert.concertDate,
      createdAt: testConcert.createdAt,
    );
    final success = await dataSource.updateConcert(updatedConcert);
    final result = await dataSource.getConcertById('c1');
    expect(success, isTrue);
    expect(result?.name, 'Updated Title');
  });

  test('updateConcert returns false for non-existent concert', () async {
    final success = await dataSource.updateConcert(testConcert);
    expect(success, isFalse);
  });

  test('upsertConcert inserts a new concert', () async {
    await dataSource.upsertConcert(testConcert);
    final result = await dataSource.getConcertById('c1');
    expect(result, isNotNull);
  });

  test('upsertConcert updates an existing concert', () async {
    await dataSource.insertConcert(testConcert);
    final updatedConcert = ConcertModel(
      id: 'c1',
      choirId: 'choir1',
      choirName: 'Test Choir',
      name: 'Upserted Title',
      concertDate: testConcert.concertDate,
      createdAt: testConcert.createdAt,
    );
    await dataSource.upsertConcert(updatedConcert);
    final result = await dataSource.getConcertById('c1');
    expect(result?.name, 'Upserted Title');
  });

  test('deleteConcert soft deletes a concert', () async {
    await dataSource.insertConcert(testConcert);
    await dataSource.deleteConcert('c1');
    final result = await dataSource.getConcertById('c1');
    expect(result, isNull);

    // Verify it's in the database but marked as deleted
    final rawConcert = await (database.select(database.concerts)..where((c) => c.id.equals('c1'))).getSingle();
    expect(rawConcert.deleted, isTrue);
  });

  group('watchConcerts', () {
    test('emits initial list of concerts', () async {
      final concert1 = domain.Concert(id: 'c1', name: 'Concert 1', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now());
      final concert2 = domain.Concert(id: 'c2', name: 'Concert 2', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now());
      
      final stream = dataSource.watchConcerts();
      
      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<ConcertModel>>().having((l) => l.length, 'length', 2)),
      ]));

      await TestDatabaseHelper.seedConcerts(database, [concert1, concert2]);
    });

    test('emits updated list when a concert is added', () async {
      final stream = dataSource.watchConcerts();

      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<ConcertModel>>().having((l) => l.length, 'length', 1)),
      ]));

      await dataSource.insertConcert(testConcert);
    });
  });

  test('getConcerts returns correct concerts', () async {
    final concert1 = ConcertModel(id: 'c1', name: 'Concert 1', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now());
    final concert2 = ConcertModel(id: 'c2', name: 'Concert 2', choirId: 'choir2', choirName: 'Choir 2', concertDate: DateTime.now(), createdAt: DateTime.now());
    
    await dataSource.insertConcert(concert1);
    await dataSource.insertConcert(concert2);

    final results = await dataSource.getConcerts();
    expect(results.length, 2);
  });

  test('getUnsyncedConcerts and markAsSynced', () async {
    await dataSource.insertConcert(testConcert, markForSync: true);

    var unsynced = await dataSource.getUnsyncedConcerts();
    expect(unsynced.length, 1);
    expect(unsynced.first.id, 'c1');

    await dataSource.markAsSynced('c1');
    unsynced = await dataSource.getUnsyncedConcerts();
    expect(unsynced, isEmpty);
  });

  test('clearAll removes all concerts', () async {
    await dataSource.insertConcert(testConcert);
    await dataSource.clearAll();
    final result = await dataSource.getConcertById('c1');
    expect(result, isNull);
  });
}
