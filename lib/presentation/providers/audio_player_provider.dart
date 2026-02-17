import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audio_player_repository_impl.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_player_repository.dart';
import 'auth_provider.dart'; // For supabaseServiceProvider
import 'concert_provider.dart'; // For databaseProvider

/// Provider for the audio player repository
///
/// This provides a single instance of the audio player throughout the app.
/// The repository manages all playback operations using just_audio.
/// It receives the local database and Supabase service so that the audio
/// handler can serve content (favorites) to Android Auto and generate
/// signed URLs for cloud-stored audio files.
final audioPlayerRepositoryProvider = Provider<AudioPlayerRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  final repository = AudioPlayerRepositoryImpl(database, supabaseService);

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

  /// Play a track from the beginning
  ///
  /// If the track has a cloud storage path, generates a signed URL for
  /// authenticated access (valid for 24 hours).
  Future<void> playTrack(
    Track track, {
    String? songName,
    String? albumName,
  }) async {
    String? signedUrl;

    // Generate signed URL for cloud-stored audio files
    if (track.storagePath != null) {
      try {
        final supabaseService = _ref.read(supabaseServiceProvider);
        final response = await supabaseService.client.storage
            .from('audio_files')
            .createSignedUrl(track.storagePath!, 86400); // 24 hours
        signedUrl = response;
      } catch (e) {
        // Log error but continue - will fall back to local file if available
      }
    }

    await _repository.playTrack(
      track,
      audioUrl: signedUrl,
      songName: songName,
      albumName: albumName,
    );
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

  /// Toggle full-track loop on/off
  Future<void> toggleTrackLoop() async {
    await _repository.setLoopMode(!_repository.isLooping);
  }

  /// Set playback speed (preserves pitch)
  Future<void> setSpeed(double speed) async {
    await _repository.setSpeed(speed);
  }
}

/// Provider for audio player controls
///
/// Use this to control playback from UI widgets.
/// Example: ref.read(audioPlayerControlsProvider).playTrack(track)
final audioPlayerControlsProvider = Provider<AudioPlayerControls>((ref) {
  return AudioPlayerControls(ref);
});
