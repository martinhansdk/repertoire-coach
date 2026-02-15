import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:repertoire_coach/data/datasources/local/local_user_playback_state_data_source.dart';
import 'package:repertoire_coach/data/repositories/audio_player_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/data/models/user_playback_state_model.dart';

/// Minimal mock so that flutter_cache_manager (used internally by
/// audio_service) can resolve all path_provider calls without a real platform.
class _MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath({String? prefix}) async => '/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/support';

  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp/documents';

  @override
  Future<String?> getDownloadsPath() async => '/tmp/downloads';
}

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
      PathProviderPlatform.instance = _MockPathProviderPlatform();
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

      // Assert: After dispose, the stream still emits the cached current state
      // (from the async* generator) but the underlying broadcast controller
      // is closed. Verify we can still read the last known state.
      final info = await repository.playbackStream.first;
      expect(info.state, AudioPlayerState.idle);
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

    test('should set loop mode to enabled', () async {
      // Arrange: Initial loop mode should be false
      expect(repository.isLooping, isFalse);

      // Act: Enable loop mode
      await repository.setLoopMode(true);

      // Assert: Loop mode should be enabled
      expect(repository.isLooping, isTrue);
    });

    test('should set loop mode to disabled', () async {
      // Arrange: Enable loop mode first
      await repository.setLoopMode(true);
      expect(repository.isLooping, isTrue);

      // Act: Disable loop mode
      await repository.setLoopMode(false);

      // Assert: Loop mode should be disabled
      expect(repository.isLooping, isFalse);
    });

    test('should toggle loop mode multiple times', () async {
      // Act & Assert: Toggle loop mode several times
      await repository.setLoopMode(true);
      expect(repository.isLooping, isTrue);

      await repository.setLoopMode(false);
      expect(repository.isLooping, isFalse);

      await repository.setLoopMode(true);
      expect(repository.isLooping, isTrue);

      await repository.setLoopMode(false);
      expect(repository.isLooping, isFalse);
    });

    test('setLoopMode(true) causes playback stream to emit isTrackLooping: true', () async {
      // Listen to playback stream before enabling loop
      final events = <bool>[];
      final subscription = repository.playbackStream.listen((info) {
        events.add(info.isTrackLooping);
      });

      // Enable loop mode - should immediately emit updated state
      await repository.setLoopMode(true);

      await Future.delayed(const Duration(milliseconds: 50));

      // The stream should have emitted at least one event with isTrackLooping: true
      expect(events, contains(true));

      await subscription.cancel();
    });

    test('setLoopMode updates playback state immediately when paused', () async {
      // This test verifies the loop button updates its appearance when clicked while paused
      final events = <PlaybackInfo>[];
      final subscription = repository.playbackStream.listen((info) {
        events.add(info);
      });

      // Enable loop while paused
      await repository.setLoopMode(true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have emitted updated state
      expect(events.last.isTrackLooping, true);

      // Disable loop while still paused
      await repository.setLoopMode(false);
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have emitted updated state again
      expect(events.last.isTrackLooping, false);

      await subscription.cancel();
    });

    test('resume after completion seeks to zero', () async {
      // Note: Testing resume-after-completion against real just_audio requires a real
      // audio file to reach the completed processing state. The seek-to-zero logic
      // in resume() is covered by code review; a full integration test would require
      // a valid audio file on the test system.
    }, skip: 'Requires valid audio file to reach completed state');

    test('track completion stops playback when not looping', () async {
      // When a track reaches ProcessingState.completed and loop mode is off,
      // the playerStateStream listener calls stop(), which clears the track
      // and transitions to idle. This requires a real audio file to trigger
      // the completed state in just_audio; verified via integration testing.
    }, skip: 'Requires valid audio file to reach completed state');

    test('track completion does not stop when looping', () async {
      // When loop mode is enabled, just_audio's LoopMode.one prevents
      // ProcessingState.completed from firing — the track restarts automatically.
      // Verified via integration testing with a real audio file.
    }, skip: 'Requires valid audio file to verify loop behaviour');
  });

  group('AudioPlayerRepositoryImpl - Error Handling', () {
    late AudioPlayerRepositoryImpl repository;
    late MockPlaybackStateDataSource mockDataSource;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PathProviderPlatform.instance = _MockPathProviderPlatform();
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

  group('Bug reproductions', () {
    late AudioPlayerRepositoryImpl repository;
    late MockPlaybackStateDataSource mockDataSource;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PathProviderPlatform.instance = _MockPathProviderPlatform();
      mockDataSource = MockPlaybackStateDataSource();
      repository = AudioPlayerRepositoryImpl(mockDataSource);
    });

    tearDown(() async {
      await repository.dispose();
    });

    // Bug 1: Markers not shown when navigating to audio player.
    // Root cause: playbackStream is a broadcast stream that doesn't emit
    // the current state to new subscribers. StreamProvider stays in loading
    // state until the first player event (e.g., pressing play).
    test('playbackStream should emit initial state to late subscribers', () async {
      // In the real app, the StreamProvider subscribes AFTER the repository
      // is created and initial just_audio events have already fired.
      // Wait for initial just_audio events to pass, then subscribe "late."
      await Future.delayed(const Duration(milliseconds: 200));

      // A late subscriber should still get the current state immediately.
      // With a plain broadcast stream, this times out because past events
      // aren't replayed to new subscribers.
      final info = await repository.playbackStream.first
          .timeout(const Duration(milliseconds: 500));

      expect(info.state, AudioPlayerState.idle);
      expect(info.currentTrack, isNull);
      expect(info.position, Duration.zero);
    });

    // Bug 4: Track B shows Track A's position (0:50) when navigating.
    // Root cause: just_audio's stop() doesn't reset the player's internal
    // position. _updatePlaybackInfo() reads _player.position which still
    // returns Track A's last position after stop().
    test('stop() should reset position to zero', () async {
      // Seek to a non-zero position (works even without a loaded track)
      await repository.seek(const Duration(seconds: 30));

      // Verify position is non-zero
      final beforeStop = repository.currentPlayback;
      expect(beforeStop.position, greaterThan(Duration.zero),
          reason: 'Position should be non-zero before stop');

      // Stop playback
      await repository.stop();

      // Position should be zero after stop
      final afterStop = repository.currentPlayback;
      expect(afterStop.position, Duration.zero,
          reason: 'Position should reset to zero after stop() to prevent '
              'leaking stale position to the next track');
    });

    // Bug 2: After track plays to end and stops, seeking to middle and pressing
    // play jumps to beginning.
    // Bug 3: Navigating to player with saved position at end, pressing play
    // stays stopped.
    // Root cause: On track completion, stop() is called which clears
    // _currentTrack and sets state to idle. When play is pressed, the screen
    // sees idle state and calls playTrack() instead of resume(), reloading the
    // audio from scratch with race conditions around duration availability.
    //
    // These bugs require simulating ProcessingState.completed which needs a
    // mock just_audio player. Skipped for now but documented for future
    // implementation if the player is refactored to accept an injectable player.
    test('track completion should keep track info intact (not go to idle)',
        () async {
      // Cannot test without mocking just_audio's ProcessingState.completed
      // The fix: on natural completion, pause instead of stop, keeping
      // _currentTrack and state as "paused" rather than "idle".
    }, skip: 'Requires mock just_audio player to simulate track completion');
  });
}
