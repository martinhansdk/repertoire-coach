import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_choir_data_source.dart';
import 'package:repertoire_coach/data/models/choir_model.dart';
import 'package:repertoire_coach/domain/entities/choir.dart' as domain;

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalChoirDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalChoirDataSource(database);
    await dataSource.clearAll();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  final testChoir = ChoirModel(
    id: 'c1',
    name: 'Test Choir',
    ownerId: 'u1',
    createdAt: DateTime.now(),
  );

  group('Choir Operations', () {
    test('createChoir and getChoirById', () async {
      await dataSource.createChoir(testChoir, 'u1');
      final result = await dataSource.getChoirById('c1');
      expect(result, isA<ChoirModel>());
      expect(result?.id, 'c1');

      final isMember = await dataSource.isMember('c1', 'u1');
      expect(isMember, isTrue);
    });

    test('updateChoir updates existing choir', () async {
      await dataSource.createChoir(testChoir, 'u1');
      final updatedChoir = ChoirModel(
        id: 'c1',
        name: 'Updated Title',
        ownerId: 'u1',
        createdAt: testChoir.createdAt,
      );
      final success = await dataSource.updateChoir(updatedChoir);
      final result = await dataSource.getChoirById('c1');
      expect(success, isTrue);
      expect(result?.name, 'Updated Title');
    });

    test('deleteChoir soft deletes a choir', () async {
      await dataSource.createChoir(testChoir, 'u1');
      await dataSource.deleteChoir('c1');
      final result = await dataSource.getChoirById('c1');
      expect(result, isNull);

      final rawChoir = await (database.select(database.choirs)..where((c) => c.id.equals('c1'))).getSingle();
      expect(rawChoir.deleted, isTrue);
    });
  });

  group('Choir Member Operations', () {
    setUp(() async {
      await dataSource.createChoir(testChoir, 'u1');
    });

    test('addMember and getChoirMembers', () async {
      await dataSource.addMember('c1', 'u2');
      final members = await dataSource.getChoirMembers('c1');
      expect(members, containsAll(['u1', 'u2']));
    });

    test('removeMember removes a member', () async {
      await dataSource.addMember('c1', 'u2');
      var members = await dataSource.getChoirMembers('c1');
      expect(members, hasLength(2));

      await dataSource.removeMember('c1', 'u2');
      members = await dataSource.getChoirMembers('c1');
      expect(members, hasLength(1));
      expect(members, isNot(contains('u2')));
    });

    test('isMember returns true for members and false for non-members', () async {
      expect(await dataSource.isMember('c1', 'u1'), isTrue);
      expect(await dataSource.isMember('c1', 'u2'), isFalse);
      await dataSource.addMember('c1', 'u2');
      expect(await dataSource.isMember('c1', 'u2'), isTrue);
    });

    test('isOwner returns true for owner and false for other users', () async {
      expect(await dataSource.isOwner('c1', 'u1'), isTrue);
      expect(await dataSource.isOwner('c1', 'u2'), isFalse);
    });

    test('getMemberCount returns correct count', () async {
      expect(await dataSource.getMemberCount('c1'), 1);
      await dataSource.addMember('c1', 'u2');
      expect(await dataSource.getMemberCount('c1'), 2);
    });
  });

  group('Watch Operations', () {
    test('watchChoirs emits updated list when a choir is added', () async {
      final stream = dataSource.watchChoirs('u1');

      expect(stream, emitsInOrder([
        emits([]),
        emits(isA<List<ChoirModel>>().having((l) => l.length, 'length', 1)),
      ]));

      await dataSource.createChoir(testChoir, 'u1');
    });
  });
}
