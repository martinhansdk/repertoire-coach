import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_choir_data_source.dart';
import 'package:repertoire_coach/data/models/choir_model.dart';
import 'package:repertoire_coach/data/repositories/choir_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/choir_repository.dart';

void main() {
  group('ChoirRepositoryImpl', () {
    late db.AppDatabase database;
    late LocalChoirDataSource dataSource;
    late ChoirRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalChoirDataSource(database);
      repository = ChoirRepositoryImpl(dataSource);

      // Seed test data
      await _seedTestData(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    group('Choir Operations', () {
      test('should create a new choir and add creator as member', () async {
        // Arrange
        const name = 'New Choir';
        const ownerId = 'user1';

        // Act
        final choirId = await repository.createChoir(name, ownerId);

        // Assert
        expect(choirId, isNotEmpty);

        // Verify choir was created
        final choir = await repository.getChoirById(choirId);
        expect(choir, isNotNull);
        expect(choir!.name, name);
        expect(choir.ownerId, ownerId);

        // Verify creator is a member
        final isMember = await repository.isMember(choirId, ownerId);
        expect(isMember, isTrue);
      });

      test('should return choirs for a specific user', () async {
        // Arrange
        const userId = 'user1';

        // Act
        final choirs = await repository.getChoirs(userId);

        // Assert
        expect(choirs, isNotEmpty);
        expect(choirs.length, 2); // user1 is member of 2 choirs

        // Verify all returned choirs have user1 as member
        for (final choir in choirs) {
          final isMember = await repository.isMember(choir.id, userId);
          expect(isMember, isTrue);
        }
      });

      test('should return empty list for user with no choirs', () async {
        // Arrange
        const userId = 'user-no-choirs';

        // Act
        final choirs = await repository.getChoirs(userId);

        // Assert
        expect(choirs, isEmpty);
      });

      test('should return choir by id', () async {
        // Arrange
        const choirId = 'choir1';

        // Act
        final choir = await repository.getChoirById(choirId);

        // Assert
        expect(choir, isNotNull);
        expect(choir!.id, choirId);
        expect(choir.name, 'City Chamber Choir');
      });

      test('should return null for non-existent choir id', () async {
        // Arrange
        const choirId = 'non-existent';

        // Act
        final choir = await repository.getChoirById(choirId);

        // Assert
        expect(choir, isNull);
      });

      test('should update choir name', () async {
        // Arrange
        const choirId = 'choir1';
        const newName = 'Updated Choir Name';
        final choir = await repository.getChoirById(choirId);
        expect(choir, isNotNull);

        final updatedChoir = ChoirModel(
          id: choir!.id,
          name: newName,
          ownerId: choir.ownerId,
          createdAt: choir.createdAt,
        );

        // Act
        await repository.updateChoir(updatedChoir);

        // Assert
        final result = await repository.getChoirById(choirId);
        expect(result, isNotNull);
        expect(result!.name, newName);
      });

      test('should soft delete choir', () async {
        // Arrange
        const choirId = 'choir1';

        // Act
        await repository.deleteChoir(choirId);

        // Assert
        final choir = await repository.getChoirById(choirId);
        expect(choir, isNull); // Should not be found after soft delete
      });
    });

    group('Membership Operations', () {
      test('should add member to choir', () async {
        // Arrange
        const choirId = 'choir1';
        const newUserId = 'user4';

        // Act
        await repository.addMember(choirId, newUserId);

        // Assert
        final isMember = await repository.isMember(choirId, newUserId);
        expect(isMember, isTrue);

        final members = await repository.getMembers(choirId);
        expect(members, contains(newUserId));
      });

      test('should remove non-owner member from choir', () async {
        // Arrange
        const choirId = 'choir1';
        const userId = 'user2'; // Not the owner

        // Act
        final removed = await repository.removeMember(choirId, userId);

        // Assert
        expect(removed, isTrue);

        final isMember = await repository.isMember(choirId, userId);
        expect(isMember, isFalse);
      });

      test('should not allow removing choir owner', () async {
        // Arrange
        const choirId = 'choir1';
        const ownerId = 'user1';

        // Act & Assert
        expect(
          () => repository.removeMember(choirId, ownerId),
          throwsA(isA<Exception>()),
        );

        // Verify owner is still a member
        final isMember = await repository.isMember(choirId, ownerId);
        expect(isMember, isTrue);
      });

      test('should return all members of a choir', () async {
        // Arrange
        const choirId = 'choir1';

        // Act
        final members = await repository.getMembers(choirId);

        // Assert
        expect(members, isNotEmpty);
        expect(members, contains('user1')); // Owner
        expect(members, contains('user2')); // Member
      });

      test('should correctly identify choir member', () async {
        // Arrange
        const choirId = 'choir1';
        const memberId = 'user1';
        const nonMemberId = 'user3';

        // Act & Assert
        final isMember = await repository.isMember(choirId, memberId);
        expect(isMember, isTrue);

        final isNotMember = await repository.isMember(choirId, nonMemberId);
        expect(isNotMember, isFalse);
      });

      test('should correctly identify choir owner', () async {
        // Arrange
        const choirId = 'choir1';
        const ownerId = 'user1';
        const nonOwnerId = 'user2';

        // Act & Assert
        final isOwner = await repository.isOwner(choirId, ownerId);
        expect(isOwner, isTrue);

        final isNotOwner = await repository.isOwner(choirId, nonOwnerId);
        expect(isNotOwner, isFalse);
      });

      test('should return correct member count', () async {
        // Arrange
        const choirId = 'choir1';

        // Act
        final count = await repository.getMemberCount(choirId);

        // Assert
        expect(count, 2); // user1 (owner) and user2
      });
    });
  });
}

/// Seed test data into the database
Future<void> _seedTestData(LocalChoirDataSource dataSource) async {
  // Create test choirs
  final testChoirs = [
    ChoirModel(
      id: 'choir1',
      name: 'City Chamber Choir',
      ownerId: 'user1',
      createdAt: DateTime(2024, 1, 1),
    ),
    ChoirModel(
      id: 'choir2',
      name: 'Community Singers',
      ownerId: 'user2',
      createdAt: DateTime(2024, 2, 1),
    ),
    ChoirModel(
      id: 'choir3',
      name: 'Vocal Ensemble',
      ownerId: 'user3',
      createdAt: DateTime(2024, 3, 1),
    ),
  ];

  // Insert choirs and add owners as members
  for (final choir in testChoirs) {
    await dataSource.createChoir(choir, choir.ownerId, markForSync: false);
  }

  // Add additional members
  await dataSource.addMember('choir1', 'user2', markForSync: false); // user2 is member of choir1
  await dataSource.addMember('choir2', 'user1', markForSync: false); // user1 is member of choir2
}
