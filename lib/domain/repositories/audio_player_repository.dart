import '../entities/loop_range.dart';
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

  /// Load and play a track from the beginning
  ///
  /// [track] - The track to play
  /// [audioUrl] - Optional URL to use instead of track's stored URL (e.g., signed URL)
  /// [songName] - Optional song name to display in notification (title field)
  /// [albumName] - Optional album name (concert name) to display in notification
  ///
  /// Throws an exception if the track has no audio source
  Future<void> playTrack(
    Track track, {
    String? audioUrl,
    String? songName,
    String? albumName,
  });

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

  /// Set the loop mode for playback
  ///
  /// [enabled] - If true, the current track will repeat when it finishes
  Future<void> setLoopMode(bool enabled);

  /// Get the current loop mode state
  bool get isLooping;

  /// Set an A-B loop range for practice
  ///
  /// When a loop range is set, playback will automatically jump back to the
  /// start position when it reaches the end position.
  ///
  /// [loopRange] - The loop range to set, or null to clear the loop
  Future<void> setLoopRange(LoopRange? loopRange);

  /// Get the current A-B loop range
  ///
  /// Returns null if no loop range is set
  LoopRange? get currentLoopRange;

  /// Check if A-B range looping is currently active
  ///
  /// This is different from [isLooping] which indicates full track repeat
  bool get isRangeLooping;

  /// Set the playback speed
  ///
  /// [speed] - The playback speed multiplier (e.g. 0.5, 0.75, 1.0, 1.25, 1.5)
  /// Speed change preserves pitch.
  Future<void> setSpeed(double speed);

  /// Get the current playback speed
  double get speed;

  /// Dispose of the audio player and release all resources
  Future<void> dispose();
}
