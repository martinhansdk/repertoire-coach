import '../entities/playback_info.dart';
import '../entities/track.dart';

/// Audio player repository interface
///
/// Defines the contract for audio playback functionality.
/// Implementations can use different audio libraries (just_audio, audioplayers, etc.)
abstract class AudioPlayerRepository {
  /// Get a stream of playback information updates
  ///
  /// This stream emits the current playback state, position, duration, etc.
  /// whenever any of these values change.
  Stream<PlaybackInfo> get playbackStream;

  /// Get the current playback information synchronously
  PlaybackInfo get currentPlayback;

  /// Load and play a track
  ///
  /// [track] - The track to play
  /// [startPosition] - Optional position to start playback from
  ///
  /// Throws an exception if the track's file path is null or invalid
  Future<void> playTrack(Track track, {Duration startPosition = Duration.zero});

  /// Resume playback if paused
  Future<void> resume();

  /// Pause playback
  Future<void> pause();

  /// Stop playback and release resources
  Future<void> stop();

  /// Seek to a specific position in the current track
  ///
  /// [position] - The position to seek to
  /// Returns the actual position seeked to (may differ if position is out of bounds)
  Future<Duration> seek(Duration position);

  /// Save the current playback position for the current track
  ///
  /// This is used to remember where the user left off
  Future<void> savePlaybackPosition();

  /// Load the saved playback position for a track
  ///
  /// [trackId] - The track to load the position for
  /// Returns the saved position, or Duration.zero if none exists
  Future<Duration> loadPlaybackPosition(String trackId);

  /// Dispose of the audio player and release all resources
  Future<void> dispose();
}
