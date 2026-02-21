import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:repertoire_coach/core/services/r2_signer_client.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/repositories/audio_player_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

import 'audio_player_repository_impl_test.mocks.dart';

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

@GenerateMocks([SupabaseService, R2SignerClient])
void main() {
  group('AudioPlayerRepositoryImpl', () {
    late AudioPlayerRepositoryImpl repository;
    late db.AppDatabase database;
    late MockSupabaseService mockSupabaseService;
    late MockR2SignerClient mockSignerClient;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PathProviderPlatform.instance = _MockPathProviderPlatform();
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      mockSupabaseService = MockSupabaseService();
      mockSignerClient = MockR2SignerClient();
      repository = AudioPlayerRepositoryImpl(database, mockSupabaseService, mockSignerClient);
    });

    tearDown(() async {
      await repository.dispose();
      await database.close();
    });

    test('should initialize with idle state', () {
      // Assert
      final playback = repository.currentPlayback;
      expect(playback.state, AudioPlayerState.idle);
      expect(playback.currentTrack, isNull);
      expect(playback.position, Duration.zero);
      expect(playback.duration, Duration.zero);
    });

    test('playbackStream should emit initial state to late subscribers', () async {
      // Wait for initial just_audio events to pass, then subscribe "late."
      await Future.delayed(const Duration(milliseconds: 200));

      // A late subscriber should still get the current state immediately.
      final info = await repository.playbackStream.first
          .timeout(const Duration(milliseconds: 500));

      expect(info.state, AudioPlayerState.idle);
      expect(info.currentTrack, isNull);
      expect(info.position, Duration.zero);
    });

    test('should throw when playing track without file path', () async {
      // Arrange
      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Test Track',
        filePath: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
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
        updatedAt: DateTime(2024, 1, 1),
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

    test('stop should reset position to zero', () async {
      // Seek to a non-zero position
      await repository.seek(const Duration(seconds: 30));

      final beforeStop = repository.currentPlayback;
      expect(beforeStop.position, greaterThan(Duration.zero),
          reason: 'Position should be non-zero before stop');

      // Stop playback
      await repository.stop();

      // Position should be zero after stop
      final afterStop = repository.currentPlayback;
      expect(afterStop.position, Duration.zero,
          reason: 'Position should reset to zero after stop()');
    });

    test('dispose should clean up resources', () async {
      // Act
      await repository.dispose();

      // Assert: After dispose, the stream still emits the cached current state
      // (from the async* generator) but the underlying broadcast controller
      // is closed.
      final info = await repository.playbackStream.first;
      expect(info.state, AudioPlayerState.idle);
    });

    test('should play valid audio file', () async {
      // Requires a valid audio file format — integration test only
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
      expect(repository.isLooping, isFalse);
      await repository.setLoopMode(true);
      expect(repository.isLooping, isTrue);
    });

    test('should set loop mode to disabled', () async {
      await repository.setLoopMode(true);
      expect(repository.isLooping, isTrue);
      await repository.setLoopMode(false);
      expect(repository.isLooping, isFalse);
    });

    test('should toggle loop mode multiple times', () async {
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
      final events = <bool>[];
      final subscription = repository.playbackStream.listen((info) {
        events.add(info.isTrackLooping);
      });

      await repository.setLoopMode(true);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, contains(true));

      await subscription.cancel();
    });

    test('setLoopMode updates playback state immediately when paused', () async {
      final events = <PlaybackInfo>[];
      final subscription = repository.playbackStream.listen((info) {
        events.add(info);
      });

      await repository.setLoopMode(true);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.last.isTrackLooping, true);

      await repository.setLoopMode(false);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(events.last.isTrackLooping, false);

      await subscription.cancel();
    });

    test('track completion keeps track loaded (not idle)',
        () async {
      // Cannot test without mocking just_audio's ProcessingState.completed.
      // The fix: on natural completion, pause instead of stop, keeping
      // _currentTrack and state as "paused" rather than "idle".
    }, skip: 'Requires mock just_audio player to simulate track completion');
  });

  group('AudioPlayerRepositoryImpl - Error Handling', () {
    late AudioPlayerRepositoryImpl repository;
    late db.AppDatabase database;
    late MockSupabaseService mockSupabaseService;
    late MockR2SignerClient mockSignerClient;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PathProviderPlatform.instance = _MockPathProviderPlatform();
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      mockSupabaseService = MockSupabaseService();
      mockSignerClient = MockR2SignerClient();
      repository = AudioPlayerRepositoryImpl(database, mockSupabaseService, mockSignerClient);
    });

    tearDown(() async {
      await repository.dispose();
      await database.close();
    });

    test('should handle track with invalid file path gracefully', () async {
      // Arrange
      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Test Track',
        filePath: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
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
