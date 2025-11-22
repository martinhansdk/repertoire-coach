import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/song.dart';

void main() {
  group('Song Entity', () {
    test('should create a valid Song instance', () {
      // Arrange
      final now = DateTime.now();
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(song.id, '1');
      expect(song.concertId, 'concert1');
      expect(song.title, 'Amazing Grace');
      expect(song.createdAt, now);
      expect(song.updatedAt, now);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final song1 = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );
      final song2 = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );
      final song3 = Song(
        id: '2',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(song1, equals(song2));
      expect(song1, isNot(equals(song3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final result = song.toString();

      // Assert
      expect(result, contains('Song'));
      expect(result, contains('id: 1'));
      expect(result, contains('concertId: concert1'));
      expect(result, contains('title: Amazing Grace'));
    });
  });
}
