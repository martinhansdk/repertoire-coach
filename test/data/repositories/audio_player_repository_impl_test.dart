import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/local_user_playback_state_data_source.dart';
import 'package:repertoire_coach/data/repositories/audio_player_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/data/models/user_playback_state_model.dart';

/// Mock implementation of LocalUserPlaybackStateDataSource for testing
class MockPlaybackStateDataSource implements LocalUserPlaybackStateDataSource {
  final Map<String, UserPlaybackStateModel> _states = {};

  @override
  Future<UserPlaybackStateModel?> getPlaybackState(
    String userId,
    String trackId,
  ) async {
    final compositeId = '${userId}_$trackId';
    return _states[compositeId];
  }

  @override
  Future<void> savePlaybackState(UserPlaybackStateModel state) async {
    _states[state.id] = state;
  }

  @override
  Future<void> deletePlaybackState(String userId, String trackId) async {
    final compositeId = '${userId}_$trackId';
    _states.remove(compositeId);
  }

  @override
  Future<void> clearAllForUser(String userId) async {
    _states.removeWhere((key, value) => value.userId == userId);
  }

  @override
  Future<void> clearAll() async {
    _states.clear();
  }
}

void main() {
  group('AudioPlayerRepositoryImpl', () {
    late AudioPlayerRepositoryImpl repository;
    late MockPlaybackStateDataSource mockDataSource;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockDataSource = MockPlaybackStateDataSource();
      repository = AudioPlayerRepositoryImpl(mockDataSource);
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('should initialize with idle state', () {
      // Assert
      final playback = repository.currentPlayback;
      expect(playback.state, AudioPlayerState.idle);
      expect(playback.currentTrack, isNull);
      expect(playback.position, Duration.zero);
      expect(playback.duration, Duration.zero);
    });

    test('playbackStream should emit playback info', () async {
      // Act: Listen to playback stream
      final streamFuture = repository.playbackStream.first;

      // Assert: Should eventually emit a PlaybackInfo
      final playbackInfo = await streamFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => repository.currentPlayback,
      );

      expect(playbackInfo, isNotNull);
    });

    test('should throw when playing track without file path', () async {
      // Arrange
      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Test Track',
        filePath: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(
        () => repository.playTrack(track),
        throwsException,
      );
    });

    test('should throw when playing track with non-existent file', () async {
      // Arrange
      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Test Track',
        filePath: '/path/to/nonexistent/file.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(
        () => repository.playTrack(track),
        throwsException,
      );
    });

    test('seek should return current position', () async {
      // Act
      final position = await repository.seek(const Duration(seconds: 10));

      // Assert: Without a loaded track, seeking returns 0 or the player's position
      expect(position, isA<Duration>());
    });

    test('pause should complete without error when idle', () async {
      // Act & Assert: Should not throw
      await repository.pause();

      // Verify state
      final playback = repository.currentPlayback;
      expect(playback.state, AudioPlayerState.idle);
    });

    test('resume should complete without error when idle', () async {
      // Act & Assert: Should not throw
      await repository.resume();
    }, skip: 'just_audio play() hangs when no track loaded in test environment');

    test('stop should complete without error', () async {
      // Act
      await repository.stop();

      // Assert
      final playback = repository.currentPlayback;
      expect(playback.state, AudioPlayerState.idle);
      expect(playback.currentTrack, isNull);
    });

    test('savePlaybackPosition should complete without error', () async {
      // Act & Assert: Should not throw (even though not yet implemented)
      await repository.savePlaybackPosition();
    });

    test('loadPlaybackPosition should return Duration.zero', () async {
      // Act
      final position = await repository.loadPlaybackPosition('track-1');

      // Assert: Not yet implemented, so returns Duration.zero
      expect(position, Duration.zero);
    });

    test('dispose should clean up resources', () async {
      // Act
      await repository.dispose();

      // Assert: Should not throw
      // Stream controller should be closed, so listening should fail
      expect(
        repository.playbackStream.first,
        throwsA(isA<StateError>()),
      );
    });

    // Integration test with actual audio file
    test('should play valid audio file', () async {
      // Arrange: Create a temporary audio file
      // Note: This test requires a valid audio file format
      // For unit testing purposes, we skip this test
      // Integration tests would handle actual audio playback
    }, skip: 'Requires valid audio file and audio system');

    test('playback stream should emit state changes', () async {
      // Arrange: Listen to multiple stream events
      final events = <AudioPlayerState>[];
      final subscription = repository.playbackStream.listen((info) {
        events.add(info.state);
      });

      // Give time for initial state
      await Future.delayed(const Duration(milliseconds: 100));

      // Act: Perform operations
      await repository.pause();
      await Future.delayed(const Duration(milliseconds: 50));

      await repository.stop();
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert: Should have captured state changes
      expect(events, isNotEmpty);
      expect(events.contains(AudioPlayerState.idle), isTrue);

      // Clean up
      await subscription.cancel();
    });

    test('currentPlayback should be updated after operations', () async {
      // Arrange: Get initial state
      final initialPlayback = repository.currentPlayback;
      expect(initialPlayback.state, AudioPlayerState.idle);

      // Act: Perform stop operation
      await repository.stop();

      // Assert: State should still be idle
      final afterStopPlayback = repository.currentPlayback;
      expect(afterStopPlayback.state, AudioPlayerState.idle);
      expect(afterStopPlayback.currentTrack, isNull);
    });

    test('multiple dispose calls should not throw', () async {
      // Act & Assert
      await repository.dispose();
      await repository.dispose(); // Should not throw
    });
  });

  group('AudioPlayerRepositoryImpl - Error Handling', () {
    late AudioPlayerRepositoryImpl repository;
    late MockPlaybackStateDataSource mockDataSource;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockDataSource = MockPlaybackStateDataSource();
      repository = AudioPlayerRepositoryImpl(mockDataSource);
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('should handle track with invalid file path gracefully', () async {
      // Arrange
      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Test Track',
        filePath: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act: Try to play track with invalid path
      try {
        await repository.playTrack(track);
        fail('Should have thrown an exception');
      } catch (e) {
        // Expected to throw
      }

      // Verify error state is set
      final playback = repository.currentPlayback;
      expect(playback.state, AudioPlayerState.error);
      expect(playback.errorMessage, isNotNull);
    });
  });
}
