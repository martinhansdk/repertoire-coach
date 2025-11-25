import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/concert_repository.dart';

void main() {
  group('ConcertRepositoryImpl', () {
    late db.AppDatabase database;
    late LocalConcertDataSource dataSource;
    late ConcertRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalConcertDataSource(database);
      repository = ConcertRepositoryImpl(dataSource);

      // Seed test data
      await _seedTestData(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('should return all concerts sorted by date', () async {
      // Act
      final concerts = await repository.getConcerts();

      // Assert
      expect(concerts, isNotEmpty);
      expect(concerts.length, 5); // We have 5 mock concerts

      // Verify upcoming concerts come first
      final now = DateTime.now();
      int firstPastIndex = concerts.indexWhere((c) => c.concertDate.isBefore(now));

      if (firstPastIndex != -1) {
        // All concerts before this index should be upcoming
        for (int i = 0; i < firstPastIndex; i++) {
          expect(concerts[i].isUpcoming, isTrue,
              reason: 'Concert at index $i should be upcoming');
        }

        // All concerts from this index onwards should be past
        for (int i = firstPastIndex; i < concerts.length; i++) {
          expect(concerts[i].isPast, isTrue,
              reason: 'Concert at index $i should be past');
        }

        // Upcoming concerts should be sorted ascending (soonest first)
        for (int i = 0; i < firstPastIndex - 1; i++) {
          expect(
            concerts[i].concertDate.isBefore(concerts[i + 1].concertDate),
            isTrue,
            reason: 'Upcoming concerts should be sorted soonest first',
          );
        }

        // Past concerts should be sorted descending (most recent first)
        for (int i = firstPastIndex; i < concerts.length - 1; i++) {
          expect(
            concerts[i].concertDate.isAfter(concerts[i + 1].concertDate),
            isTrue,
            reason: 'Past concerts should be sorted most recent first',
          );
        }
      }
    });

    test('should return concerts for specific choir', () async {
      // Arrange
      const choirId = 'choir1';

      // Act
      final concerts = await repository.getConcertsByChoir(choirId);

      // Assert
      expect(concerts, isNotEmpty);
      for (final concert in concerts) {
        expect(concert.choirId, choirId);
      }
    });

    test('should return empty list for non-existent choir', () async {
      // Arrange
      const choirId = 'non-existent';

      // Act
      final concerts = await repository.getConcertsByChoir(choirId);

      // Assert
      expect(concerts, isEmpty);
    });

    test('should return concert by id', () async {
      // Arrange
      const concertId = '1';

      // Act
      final concert = await repository.getConcertById(concertId);

      // Assert
      expect(concert, isNotNull);
      expect(concert!.id, concertId);
    });

    test('should return null for non-existent concert id', () async {
      // Arrange
      const concertId = 'non-existent';

      // Act
      final concert = await repository.getConcertById(concertId);

      // Assert
      expect(concert, isNull);
    });

    test('should create a new concert', () async {
      // Arrange
      final newConcert = ConcertModel(
        id: 'new-concert',
        choirId: 'choir1',
        choirName: 'City Chamber Choir',
        name: 'New Year Concert',
        concertDate: DateTime(2025, 1, 1),
        createdAt: DateTime.now(),
      );

      // Act
      await repository.createConcert(newConcert);

      // Assert - verify it was created
      final retrieved = await repository.getConcertById('new-concert');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'new-concert');
      expect(retrieved.name, 'New Year Concert');
      expect(retrieved.choirId, 'choir1');
    });

    test('should update an existing concert', () async {
      // Arrange
      final existingConcert = await repository.getConcertById('1');
      expect(existingConcert, isNotNull);

      final updatedConcert = ConcertModel(
        id: '1',
        choirId: existingConcert!.choirId,
        choirName: existingConcert.choirName,
        name: 'Updated Concert Name',
        concertDate: DateTime(2025, 5, 20),
        createdAt: existingConcert.createdAt,
      );

      // Act
      final success = await repository.updateConcert(updatedConcert);

      // Assert
      expect(success, isTrue);

      // Verify the concert was updated
      final retrieved = await repository.getConcertById('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Updated Concert Name');
      expect(retrieved.concertDate, DateTime(2025, 5, 20));
    });

    test('should return false when updating non-existent concert', () async {
      // Arrange
      final nonExistentConcert = ConcertModel(
        id: 'non-existent',
        choirId: 'choir1',
        choirName: 'City Chamber Choir',
        name: 'Should Not Update',
        concertDate: DateTime(2025, 1, 1),
        createdAt: DateTime.now(),
      );

      // Act
      final success = await repository.updateConcert(nonExistentConcert);

      // Assert
      expect(success, isFalse);
    });

    test('should delete a concert (soft delete)', () async {
      // Arrange
      const concertId = '1';

      // Verify concert exists before deletion
      final beforeDelete = await repository.getConcertById(concertId);
      expect(beforeDelete, isNotNull);

      // Act
      await repository.deleteConcert(concertId);

      // Assert - concert should no longer be retrievable
      final afterDelete = await repository.getConcertById(concertId);
      expect(afterDelete, isNull);

      // Verify it's removed from the concerts list
      final allConcerts = await repository.getConcerts();
      expect(allConcerts.every((c) => c.id != concertId), isTrue);
    });

    test('should handle deleting non-existent concert gracefully', () async {
      // Act & Assert - should not throw
      await repository.deleteConcert('non-existent-id');
    });

  });
}

/// Seed test data into the database
Future<void> _seedTestData(LocalConcertDataSource dataSource) async {
  final testConcerts = [
    ConcertModel(
      id: '1',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Spring Concert 2025',
      concertDate: DateTime(2025, 4, 15),
      createdAt: DateTime(2024, 12, 1),
    ),
    ConcertModel(
      id: '2',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Christmas Concert 2024',
      concertDate: DateTime(2024, 12, 20),
      createdAt: DateTime(2024, 10, 1),
    ),
    ConcertModel(
      id: '3',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Summer Festival',
      concertDate: DateTime(2025, 6, 10),
      createdAt: DateTime(2024, 11, 15),
    ),
    ConcertModel(
      id: '4',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Autumn Recital',
      concertDate: DateTime(2024, 10, 5),
      createdAt: DateTime(2024, 8, 1),
    ),
    ConcertModel(
      id: '5',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Winter Showcase',
      concertDate: DateTime(2025, 2, 14),
      createdAt: DateTime(2024, 11, 20),
    ),
  ];

  for (final concert in testConcerts) {
    await dataSource.upsertConcert(concert, markForSync: false);
  }
}
