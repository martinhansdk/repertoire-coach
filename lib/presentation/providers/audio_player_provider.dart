import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_user_playback_state_data_source.dart';
import '../../data/repositories/audio_player_repository_impl.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_player_repository.dart';
import 'concert_provider.dart'; // For databaseProvider

/// Provider for the user playback state data source
final playbackStateDataSourceProvider = Provider<LocalUserPlaybackStateDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalUserPlaybackStateDataSource(database);
});

/// Provider for the audio player repository
///
/// This provides a single instance of the audio player throughout the app.
/// The repository manages all playback operations using just_audio.
final audioPlayerRepositoryProvider = Provider<AudioPlayerRepository>((ref) {
  final playbackStateDataSource = ref.watch(playbackStateDataSourceProvider);
  final repository = AudioPlayerRepositoryImpl(playbackStateDataSource);

  // Dispose the audio player when the provider is disposed
  ref.onDispose(() {
    repository.dispose();
  });

  return repository;
});

/// Stream provider for playback information
///
/// Provides real-time updates about the current playback state, position, etc.
/// UI widgets can watch this to display play/pause buttons, progress bars, etc.
final playbackInfoProvider = StreamProvider<PlaybackInfo>((ref) {
  final repository = ref.watch(audioPlayerRepositoryProvider);
  return repository.playbackStream;
});

/// Provider for the current playback info (synchronous)
///
/// This provides the current playback state without requiring async/stream handling.
/// Useful for immediate state checks.
final currentPlaybackProvider = Provider<PlaybackInfo>((ref) {
  final repository = ref.watch(audioPlayerRepositoryProvider);
  return repository.currentPlayback;
});

/// Helper methods for controlling audio playback
///
/// These methods can be called from UI widgets to control playback.
/// They return the audio player repository which handles the operations.
class AudioPlayerControls {
  final Ref _ref;

  AudioPlayerControls(this._ref);

  AudioPlayerRepository get _repository =>
      _ref.read(audioPlayerRepositoryProvider);

  /// Play a track from the beginning or a specific position
  Future<void> playTrack(Track track, {Duration startPosition = Duration.zero}) async {
    await _repository.playTrack(track, startPosition: startPosition);
  }

  /// Resume playback if paused
  Future<void> resume() async {
    await _repository.resume();
  }

  /// Pause playback
  Future<void> pause() async {
    await _repository.pause();
  }

  /// Stop playback completely
  Future<void> stop() async {
    await _repository.stop();
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    await _repository.seek(position);
  }

  /// Toggle play/pause based on current state
  Future<void> togglePlayPause() async {
    final currentState = _repository.currentPlayback.state;
    if (currentState == AudioPlayerState.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Save the current playback position
  Future<void> savePosition() async {
    await _repository.savePlaybackPosition();
  }

  /// Load the saved position for a track
  Future<Duration> loadPosition(String trackId) async {
    return await _repository.loadPlaybackPosition(trackId);
  }
}

/// Provider for audio player controls
///
/// Use this to control playback from UI widgets.
/// Example: ref.read(audioPlayerControlsProvider).playTrack(track)
final audioPlayerControlsProvider = Provider<AudioPlayerControls>((ref) {
  return AudioPlayerControls(ref);
});
