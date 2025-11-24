import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/choir_member.dart';

void main() {
  group('ChoirMember Entity', () {
    test('should create a valid ChoirMember instance', () {
      // Arrange
      final now = DateTime.now();
      final choirMember = ChoirMember(
        choirId: 'choir1',
        userId: 'user1',
        joinedAt: now,
      );

      // Assert
      expect(choirMember.choirId, 'choir1');
      expect(choirMember.userId, 'user1');
      expect(choirMember.joinedAt, now);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final member1 = ChoirMember(
        choirId: 'choir1',
        userId: 'user1',
        joinedAt: now,
      );
      final member2 = ChoirMember(
        choirId: 'choir1',
        userId: 'user1',
        joinedAt: now,
      );
      final member3 = ChoirMember(
        choirId: 'choir1',
        userId: 'user2',
        joinedAt: now,
      );

      // Assert
      expect(member1, equals(member2));
      expect(member1, isNot(equals(member3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final now = DateTime.now();
      final choirMember = ChoirMember(
        choirId: 'choir1',
        userId: 'user1',
        joinedAt: now,
      );

      // Act
      final result = choirMember.toString();

      // Assert
      expect(result, contains('ChoirMember'));
      expect(result, contains('choirId: choir1'));
      expect(result, contains('userId: user1'));
      expect(result, contains('joinedAt:'));
    });
  });
}
