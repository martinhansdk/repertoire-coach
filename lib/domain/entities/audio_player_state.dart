/// Represents the current state of the audio player
enum AudioPlayerState {
  /// Player is idle (no track loaded or player is stopped)
  idle,

  /// Player is loading/buffering audio
  loading,

  /// Player is playing audio
  playing,

  /// Player is paused
  paused,

  /// Player encountered an error
  error,
}
