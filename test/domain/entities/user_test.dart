import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/user.dart';

void main() {
  group('User Entity', () {
    test('should create a valid User instance', () {
      // Arrange
      final now = DateTime.now();
      final user = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: ['choir1', 'choir2'],
        lastAccessedConcertId: 'concert1',
        languagePreference: 'en',
        createdAt: now,
      );

      // Assert
      expect(user.id, '1');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.choirIds, ['choir1', 'choir2']);
      expect(user.lastAccessedConcertId, 'concert1');
      expect(user.languagePreference, 'en');
      expect(user.createdAt, now);
    });

    test('should support null lastAccessedConcertId', () {
      // Arrange
      final user = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: [],
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(user.lastAccessedConcertId, isNull);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final user1 = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );
      final user2 = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );
      final user3 = User(
        id: '2',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );

      // Assert
      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final user = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: ['choir1'],
        lastAccessedConcertId: 'concert1',
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );

      // Act
      final result = user.toString();

      // Assert
      expect(result, contains('User'));
      expect(result, contains('id: 1'));
      expect(result, contains('email: test@example.com'));
      expect(result, contains('displayName: Test User'));
      expect(result, contains('languagePreference: en'));
    });
  });
}
