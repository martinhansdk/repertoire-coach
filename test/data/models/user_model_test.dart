import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/user_model.dart';
import 'package:repertoire_coach/domain/entities/user.dart';

void main() {
  group('UserModel', () {
    test('should be a subclass of User entity', () {
      // Arrange
      final userModel = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(userModel, isA<User>());
    });

    test('should create UserModel from User entity', () {
      // Arrange
      final now = DateTime.now();
      final user = User(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1', 'choir2'],
        lastAccessedConcertId: 'concert1',
        languagePreference: 'da',
        createdAt: now,
      );

      // Act
      final userModel = UserModel.fromEntity(user);

      // Assert
      expect(userModel.id, user.id);
      expect(userModel.email, user.email);
      expect(userModel.displayName, user.displayName);
      expect(userModel.choirIds, user.choirIds);
      expect(userModel.lastAccessedConcertId, user.lastAccessedConcertId);
      expect(userModel.languagePreference, user.languagePreference);
      expect(userModel.createdAt, user.createdAt);
    });

    test('should convert UserModel to User entity', () {
      // Arrange
      final now = DateTime.now();
      final userModel = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );

      // Act
      final user = userModel.toEntity();

      // Assert
      expect(user, isA<User>());
      expect(user.id, userModel.id);
      expect(user.email, userModel.email);
      expect(user.displayName, userModel.displayName);
      expect(user.choirIds, userModel.choirIds);
      expect(user.languagePreference, userModel.languagePreference);
      expect(user.createdAt, userModel.createdAt);
    });

    test('should handle null lastAccessedConcertId', () {
      // Arrange
      final userModel = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(userModel.lastAccessedConcertId, isNull);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final userModel1 = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );
      final userModel2 = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );
      final userModel3 = UserModel(
        id: '2',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: now,
      );

      // Assert
      expect(userModel1, equals(userModel2));
      expect(userModel1, isNot(equals(userModel3)));
    });

    test('should handle different language preferences', () {
      // Arrange
      final userModelEn = UserModel(
        id: '1',
        email: 'test@example.com',
        displayName: 'Test User',
        choirIds: const ['choir1'],
        languagePreference: 'en',
        createdAt: DateTime.now(),
      );
      final userModelDa = UserModel(
        id: '2',
        email: 'test2@example.com',
        displayName: 'Test User 2',
        choirIds: const ['choir1'],
        languagePreference: 'da',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(userModelEn.languagePreference, 'en');
      expect(userModelDa.languagePreference, 'da');
    });
  });
}
