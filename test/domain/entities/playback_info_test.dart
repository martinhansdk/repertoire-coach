import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('PlaybackInfo Entity', () {
    final now = DateTime(2025, 1, 15, 10, 30);
    final track = Track(
      id: 'track-1',
      songId: 'song-1',
      name: 'Soprano Part',
      filePath: '/path/to/audio.mp3',
      createdAt: now,
      updatedAt: now,
    );

    test('should create PlaybackInfo with all fields', () {
      final playbackInfo = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 180),
      );

      expect(playbackInfo.currentTrack, track);
      expect(playbackInfo.state, AudioPlayerState.playing);
      expect(playbackInfo.position, const Duration(seconds: 30));
      expect(playbackInfo.duration, const Duration(seconds: 180));
      expect(playbackInfo.errorMessage, isNull);
    });

    test('should create idle PlaybackInfo', () {
      const playbackInfo = PlaybackInfo.idle();

      expect(playbackInfo.currentTrack, isNull);
      expect(playbackInfo.state, AudioPlayerState.idle);
      expect(playbackInfo.position, Duration.zero);
      expect(playbackInfo.duration, Duration.zero);
      expect(playbackInfo.errorMessage, isNull);
    });

    test('should create error PlaybackInfo', () {
      const playbackInfo = PlaybackInfo.error('File not found');

      expect(playbackInfo.currentTrack, isNull);
      expect(playbackInfo.state, AudioPlayerState.error);
      expect(playbackInfo.position, Duration.zero);
      expect(playbackInfo.duration, Duration.zero);
      expect(playbackInfo.errorMessage, 'File not found');
    });

    test('isPlaying should return true when playing', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        position: Duration.zero,
        duration: Duration.zero,
      );

      expect(playbackInfo.isPlaying, isTrue);
    });

    test('isPlaying should return false when not playing', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.paused,
        position: Duration.zero,
        duration: Duration.zero,
      );

      expect(playbackInfo.isPlaying, isFalse);
    });

    test('isPaused should return true when paused', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.paused,
        position: Duration.zero,
        duration: Duration.zero,
      );

      expect(playbackInfo.isPaused, isTrue);
    });

    test('isLoading should return true when loading', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.loading,
        position: Duration.zero,
        duration: Duration.zero,
      );

      expect(playbackInfo.isLoading, isTrue);
    });

    test('hasError should return true when in error state', () {
      const playbackInfo = PlaybackInfo.error('Test error');

      expect(playbackInfo.hasError, isTrue);
    });

    test('hasTrack should return true when track is loaded', () {
      final playbackInfo = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.paused,
        position: Duration.zero,
        duration: Duration.zero,
      );

      expect(playbackInfo.hasTrack, isTrue);
    });

    test('hasTrack should return false when no track', () {
      const playbackInfo = PlaybackInfo.idle();

      expect(playbackInfo.hasTrack, isFalse);
    });

    test('progress should calculate correctly', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        position: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );

      expect(playbackInfo.progress, 0.25);
    });

    test('progress should return 0 when duration is zero', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.idle,
        position: Duration(seconds: 10),
        duration: Duration.zero,
      );

      expect(playbackInfo.progress, 0.0);
    });

    test('progress should handle position at end', () {
      const playbackInfo = PlaybackInfo(
        state: AudioPlayerState.paused,
        position: Duration(seconds: 120),
        duration: Duration(seconds: 120),
      );

      expect(playbackInfo.progress, 1.0);
    });

    test('copyWith should create new instance with updated values', () {
      const original = PlaybackInfo.idle();

      final updated = original.copyWith(
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 10),
      );

      expect(updated.state, AudioPlayerState.playing);
      expect(updated.position, const Duration(seconds: 10));
      expect(updated.duration, Duration.zero); // Unchanged
    });

    test('copyWith should update track', () {
      const original = PlaybackInfo.idle();

      final updated = original.copyWith(currentTrack: track);

      expect(updated.currentTrack, track);
    });

    test('copyWith should clear track when clearTrack is true', () {
      final original = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.paused,
        position: Duration.zero,
        duration: Duration.zero,
      );

      final updated = original.copyWith(clearTrack: true);

      expect(updated.currentTrack, isNull);
    });

    test('copyWith should clear error when clearError is true', () {
      const original = PlaybackInfo.error('Test error');

      final updated = original.copyWith(
        clearError: true,
        state: AudioPlayerState.idle,
      );

      expect(updated.errorMessage, isNull);
      expect(updated.state, AudioPlayerState.idle);
    });

    test('should support equality comparison', () {
      final playbackInfo1 = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );

      final playbackInfo2 = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );

      expect(playbackInfo1, equals(playbackInfo2));
    });

    test('should not be equal if state differs', () {
      final playbackInfo1 = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );

      final playbackInfo2 = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.paused,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );

      expect(playbackInfo1, isNot(equals(playbackInfo2)));
    });

    test('toString should contain relevant information', () {
      final playbackInfo = PlaybackInfo(
        currentTrack: track,
        state: AudioPlayerState.playing,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
      );

      final string = playbackInfo.toString();
      expect(string, contains('Soprano Part'));
      expect(string, contains('playing'));
      expect(string, contains('30s'));
      expect(string, contains('120s'));
    });
  });
}
