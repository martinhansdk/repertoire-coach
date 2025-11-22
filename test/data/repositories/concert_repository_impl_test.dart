import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/concert_repository.dart';

void main() {
  group('ConcertRepositoryImpl', () {
    late ConcertRepository repository;

    setUp(() {
      repository = ConcertRepositoryImpl();
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

    test('should simulate network delay', () async {
      // Arrange
      final stopwatch = Stopwatch()..start();

      // Act
      await repository.getConcerts();
      stopwatch.stop();

      // Assert - should take at least 300ms (the mock delay)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(250));
    });
  });
}
