import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/user_playback_state_model.dart';
import 'package:repertoire_coach/domain/entities/user_playback_state.dart';

void main() {
  group('UserPlaybackStateModel', () {
    test('should be a subclass of UserPlaybackState entity', () {
      // Arrange
      final stateModel = UserPlaybackStateModel(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(stateModel, isA<UserPlaybackState>());
    });

    test('should create UserPlaybackStateModel from UserPlaybackState entity', () {
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

      // Act
      final stateModel = UserPlaybackStateModel.fromEntity(state);

      // Assert
      expect(stateModel.id, state.id);
      expect(stateModel.userId, state.userId);
      expect(stateModel.songId, state.songId);
      expect(stateModel.trackId, state.trackId);
      expect(stateModel.position, state.position);
      expect(stateModel.updatedAt, state.updatedAt);
    });

    test('should convert UserPlaybackStateModel to UserPlaybackState entity', () {
      // Arrange
      final now = DateTime.now();
      final stateModel = UserPlaybackStateModel(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );

      // Act
      final state = stateModel.toEntity();

      // Assert
      expect(state, isA<UserPlaybackState>());
      expect(state.id, stateModel.id);
      expect(state.userId, stateModel.userId);
      expect(state.songId, stateModel.songId);
      expect(state.trackId, stateModel.trackId);
      expect(state.position, stateModel.position);
      expect(state.updatedAt, stateModel.updatedAt);
    });

    test('should support zero position', () {
      // Arrange
      final stateModel = UserPlaybackStateModel(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 0,
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(stateModel.position, 0);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final stateModel1 = UserPlaybackStateModel(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );
      final stateModel2 = UserPlaybackStateModel(
        id: 'user1_song1_track1',
        userId: 'user1',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );
      final stateModel3 = UserPlaybackStateModel(
        id: 'user2_song1_track1',
        userId: 'user2',
        songId: 'song1',
        trackId: 'track1',
        position: 45000,
        updatedAt: now,
      );

      // Assert
      expect(stateModel1, equals(stateModel2));
      expect(stateModel1, isNot(equals(stateModel3)));
    });

    test('should maintain all properties through entity conversion', () {
      // Arrange
      final now = DateTime.now();
      final originalState = UserPlaybackState(
        id: 'user123_song456_track789',
        userId: 'user123',
        songId: 'song456',
        trackId: 'track789',
        position: 120000,
        updatedAt: now,
      );

      // Act
      final stateModel = UserPlaybackStateModel.fromEntity(originalState);
      final convertedState = stateModel.toEntity();

      // Assert
      expect(convertedState, equals(originalState));
    });
  });
}
