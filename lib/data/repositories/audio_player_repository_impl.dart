import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart' as ja;
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_player_repository.dart';

/// Implementation of AudioPlayerRepository using just_audio
class AudioPlayerRepositoryImpl implements AudioPlayerRepository {
  final ja.AudioPlayer _player;
  final StreamController<PlaybackInfo> _playbackController;

  Track? _currentTrack;
  PlaybackInfo _currentPlaybackInfo;

  AudioPlayerRepositoryImpl()
      : _player = ja.AudioPlayer(),
        _playbackController = StreamController<PlaybackInfo>.broadcast(),
        _currentPlaybackInfo = const PlaybackInfo.idle() {
    _initializePlayerListeners();
  }

  /// Initialize listeners for the just_audio player
  void _initializePlayerListeners() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      _updatePlaybackInfo();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      _updatePlaybackInfo();
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      _updatePlaybackInfo();
    });
  }

  /// Update and broadcast current playback information
  void _updatePlaybackInfo() {
    final state = _mapPlayerState(_player.playerState);
    final position = _player.position;
    final duration = _player.duration ?? Duration.zero;

    _currentPlaybackInfo = PlaybackInfo(
      currentTrack: _currentTrack,
      state: state,
      position: position,
      duration: duration,
    );

    _playbackController.add(_currentPlaybackInfo);
  }

  /// Map just_audio player state to our AudioPlayerState
  AudioPlayerState _mapPlayerState(ja.PlayerState playerState) {
    if (playerState.processingState == ja.ProcessingState.loading ||
        playerState.processingState == ja.ProcessingState.buffering) {
      return AudioPlayerState.loading;
    }

    if (playerState.playing) {
      return AudioPlayerState.playing;
    }

    if (playerState.processingState == ja.ProcessingState.completed ||
        playerState.processingState == ja.ProcessingState.idle) {
      return _currentTrack == null ? AudioPlayerState.idle : AudioPlayerState.paused;
    }

    return AudioPlayerState.paused;
  }

  @override
  Stream<PlaybackInfo> get playbackStream => _playbackController.stream;

  @override
  PlaybackInfo get currentPlayback => _currentPlaybackInfo;

  @override
  Future<void> playTrack(Track track, {Duration startPosition = Duration.zero}) async {
    if (track.filePath == null) {
      final errorInfo = PlaybackInfo.error('Track has no audio file');
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      throw Exception('Track has no audio file');
    }

    try {
      // Check if file exists
      final file = File(track.filePath!);
      if (!await file.exists()) {
        final errorInfo = PlaybackInfo.error('Audio file not found: ${track.filePath}');
        _currentPlaybackInfo = errorInfo;
        _playbackController.add(errorInfo);
        throw Exception('Audio file not found');
      }

      _currentTrack = track;

      // Set audio source to file
      await _player.setFilePath(track.filePath!);

      // Seek to start position if specified
      if (startPosition > Duration.zero) {
        await _player.seek(startPosition);
      }

      // Start playback
      await _player.play();

      _updatePlaybackInfo();
    } catch (e) {
      final errorInfo = PlaybackInfo.error('Failed to play track: $e');
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    await _player.play();
    _updatePlaybackInfo();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _updatePlaybackInfo();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
    _updatePlaybackInfo();
  }

  @override
  Future<Duration> seek(Duration position) async {
    await _player.seek(position);
    _updatePlaybackInfo();
    return _player.position;
  }

  @override
  Future<void> savePlaybackPosition() async {
    // TODO: Implement playback position saving to Drift database
    // This will be implemented when we create the playback state data source
  }

  @override
  Future<Duration> loadPlaybackPosition(String trackId) async {
    // TODO: Implement playback position loading from Drift database
    // This will be implemented when we create the playback state data source
    return Duration.zero;
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _playbackController.close();
  }
}
