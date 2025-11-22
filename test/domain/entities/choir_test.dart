import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';

void main() {
  group('Choir Entity', () {
    test('should create a valid Choir instance', () {
      // Arrange
      final now = DateTime.now();
      final choir = Choir(
        id: '1',
        name: 'Test Choir',
        ownerId: 'user1',
        createdAt: now,
      );

      // Assert
      expect(choir.id, '1');
      expect(choir.name, 'Test Choir');
      expect(choir.ownerId, 'user1');
      expect(choir.createdAt, now);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final choir1 = Choir(
        id: '1',
        name: 'Test Choir',
        ownerId: 'user1',
        createdAt: now,
      );
      final choir2 = Choir(
        id: '1',
        name: 'Test Choir',
        ownerId: 'user1',
        createdAt: now,
      );
      final choir3 = Choir(
        id: '2',
        name: 'Test Choir',
        ownerId: 'user1',
        createdAt: now,
      );

      // Assert
      expect(choir1, equals(choir2));
      expect(choir1, isNot(equals(choir3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final now = DateTime.now();
      final choir = Choir(
        id: '1',
        name: 'Test Choir',
        ownerId: 'user1',
        createdAt: now,
      );

      // Act
      final result = choir.toString();

      // Assert
      expect(result, contains('Choir'));
      expect(result, contains('id: 1'));
      expect(result, contains('name: Test Choir'));
      expect(result, contains('ownerId: user1'));
    });
  });
}
