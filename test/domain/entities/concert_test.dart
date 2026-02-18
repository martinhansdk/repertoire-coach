import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';

void main() {
  group('Concert Entity', () {
    test('should create a valid Concert instance', () {
      // Arrange
      final now = DateTime.now();
      final concertDate = DateTime(2025, 4, 15);
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: concertDate,
        createdAt: now,
      );

      // Assert
      expect(concert.id, '1');
      expect(concert.choirId, 'choir1');
      expect(concert.choirName, 'Test Choir');
      expect(concert.name, 'Spring Concert');
      expect(concert.concertDate, concertDate);
      expect(concert.createdAt, now);
    });

    test('should correctly identify upcoming concerts', () {
      // Arrange
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Future Concert',
        concertDate: futureDate,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(concert.isUpcoming, isTrue);
      expect(concert.isPast, isFalse);
    });

    test('should correctly identify past concerts', () {
      // Arrange
      final pastDate = DateTime.now().subtract(const Duration(days: 30));
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Past Concert',
        concertDate: pastDate,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(concert.isUpcoming, isFalse);
      expect(concert.isPast, isTrue);
    });

    test('should support equality comparison', () {
      // Arrange
      final concertDate = DateTime(2025, 4, 15);
      final now = DateTime.now();

      final concert1 = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Concert',
        concertDate: concertDate,
        createdAt: now,
      );
      final concert2 = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Concert',
        concertDate: concertDate,
        createdAt: now,
      );
      final concert3 = Concert(
        id: '2',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Concert',
        concertDate: concertDate,
        createdAt: now,
      );

      // Assert
      expect(concert1, equals(concert2));
      expect(concert1, isNot(equals(concert3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final concertDate = DateTime(2025, 4, 15);
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: concertDate,
        createdAt: DateTime.now(),
      );

      // Act
      final result = concert.toString();

      // Assert
      expect(result, contains('Concert'));
      expect(result, contains('id: 1'));
      expect(result, contains('name: Spring Concert'));
      expect(result, contains('choir: Test Choir'));
    });
  });
}
