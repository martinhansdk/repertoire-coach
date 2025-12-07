import 'package:equatable/equatable.dart';
import 'audio_player_state.dart';
import 'loop_range.dart';
import 'track.dart';

/// Contains all information about the current playback session
class PlaybackInfo extends Equatable {
  final Track? currentTrack;
  final AudioPlayerState state;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final LoopRange? loopRange;

  const PlaybackInfo({
    this.currentTrack,
    required this.state,
    required this.position,
    required this.duration,
    this.errorMessage,
    this.loopRange,
  });

  /// Create an idle/initial playback info
  const PlaybackInfo.idle()
      : currentTrack = null,
        state = AudioPlayerState.idle,
        position = Duration.zero,
        duration = Duration.zero,
        errorMessage = null,
        loopRange = null;

  /// Create a playback info with error state
  const PlaybackInfo.error(String message)
      : currentTrack = null,
        state = AudioPlayerState.error,
        position = Duration.zero,
        duration = Duration.zero,
        errorMessage = message,
        loopRange = null;

  /// Check if player is currently playing
  bool get isPlaying => state == AudioPlayerState.playing;

  /// Check if player is paused
  bool get isPaused => state == AudioPlayerState.paused;

  /// Check if player is loading
  bool get isLoading => state == AudioPlayerState.loading;

  /// Check if player has an error
  bool get hasError => state == AudioPlayerState.error;

  /// Check if a track is loaded
  bool get hasTrack => currentTrack != null;

  /// Check if A-B loop is active
  bool get isLooping => loopRange != null;

  /// Get playback progress as a value between 0 and 1
  double get progress {
    if (duration.inMicroseconds == 0) return 0.0;
    return position.inMicroseconds / duration.inMicroseconds;
  }

  /// Copy with new values
  PlaybackInfo copyWith({
    Track? currentTrack,
    bool clearTrack = false,
    AudioPlayerState? state,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
    LoopRange? loopRange,
    bool clearLoop = false,
  }) {
    return PlaybackInfo(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      state: state ?? this.state,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loopRange: clearLoop ? null : (loopRange ?? this.loopRange),
    );
  }

  @override
  List<Object?> get props => [
        currentTrack,
        state,
        position,
        duration,
        errorMessage,
        loopRange,
      ];

  @override
  String toString() {
    return 'PlaybackInfo(track: ${currentTrack?.name}, state: $state, '
        'position: ${position.inSeconds}s, duration: ${duration.inSeconds}s)';
  }
}
