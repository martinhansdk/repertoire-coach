import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/user_playback_state.dart';

void main() {
  group('UserPlaybackState Entity', () {
    test('should create a valid UserPlaybackState instance', () {
      // Arrange
      final now = DateTime.now();
      final state = UserPlaybackState(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );

      // Assert
      expect(state.id, 'user1_song1_track1');
      expect(state.userId, 'user1');
      expect(state.songId, 'song1');
      expect(state.trackId, 'track1');
      expect(state.position, 45000);
      expect(state.updatedAt, now);
    });

    test('should support zero position', () {
      // Arrange
      final state = UserPlaybackState(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 0,
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(state.position, 0);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final state1 = UserPlaybackState(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );
      final state2 = UserPlaybackState(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );
      final state3 = UserPlaybackState(
        id: 'user2_song1_track1',
        userId: 'user2',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );

      // Assert
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final state = UserPlaybackState(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: DateTime.now(),
      );

      // Act
      final result = state.toString();

      // Assert
      expect(result, contains('UserPlaybackState'));
      expect(result, contains('id: user1_song1_track1'));
      expect(result, contains('userId: user1'));
      expect(result, contains('trackId: track1'));
      expect(result, contains('position: 45000ms'));
    });
  });
}
