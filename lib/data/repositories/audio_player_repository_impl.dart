import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/loop_range.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../datasources/local/local_user_playback_state_data_source.dart';
import '../models/user_playback_state_model.dart';

/// Hardcoded user ID for local-first mode (before authentication)
const String _currentUserId = 'local-user-1';

/// Implementation of AudioPlayerRepository using just_audio
class AudioPlayerRepositoryImpl implements AudioPlayerRepository {
  final ja.AudioPlayer _player;
  final StreamController<PlaybackInfo> _playbackController;
  final LocalUserPlaybackStateDataSource _playbackStateDataSource;
  AudioHandler? _audioHandler;

  Track? _currentTrack;
  String? _currentSongId;
  PlaybackInfo _currentPlaybackInfo;
  Timer? _autoSaveTimer;
  bool _isLooping = false;
  LoopRange? _loopRange;
  StreamSubscription<Duration>? _loopSubscription;

  AudioPlayerRepositoryImpl(this._playbackStateDataSource)
      : _player = ja.AudioPlayer(),
        _playbackController = StreamController<PlaybackInfo>.broadcast(),
        _currentPlaybackInfo = const PlaybackInfo.idle() {
    _initializePlayerListeners();
    _configureAudioSession();
    _initializeAudioService();
  }

  /// Configure audio session for background playback
  void _configureAudioSession() async {
    // Configure the audio session to continue playing in background
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  /// Initialize audio service for background playback with media notifications
  void _initializeAudioService() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => _AudioPlayerHandler(_player),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.repertoire_coach.audio',
          androidNotificationChannelName: 'Repertoire Coach Audio',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,
        ),
      );
    } catch (e) {
      // If audio service fails to initialize (e.g., on desktop platforms),
      // continue without it. Background playback will still work on iOS/Android
      // via audio_session configuration alone.
    }
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
      loopRange: _loopRange,
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
      _currentSongId = track.songId;

      // Set audio source to file
      await _player.setFilePath(track.filePath!);

      // Load saved position if no start position specified
      Duration seekPosition = startPosition;
      if (startPosition == Duration.zero) {
        seekPosition = await loadPlaybackPosition(track.id);
      }

      // Seek to position if needed
      if (seekPosition > Duration.zero) {
        await _player.seek(seekPosition);
      }

      // Update media item for notification
      await _updateMediaItem();

      // Start playback
      await _player.play();

      // Start auto-save timer (save position every 5 seconds while playing)
      _startAutoSaveTimer();

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
    _startAutoSaveTimer();
    _updatePlaybackInfo();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _stopAutoSaveTimer();
    await savePlaybackPosition(); // Save position on pause
    _updatePlaybackInfo();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _stopAutoSaveTimer();
    await savePlaybackPosition(); // Save position on stop
    _currentTrack = null;
    _currentSongId = null;
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
    if (_currentTrack == null || _currentSongId == null) {
      return; // Nothing to save
    }

    final position = _player.position;
    if (position == Duration.zero) {
      return; // Don't save if at the beginning
    }

    final state = UserPlaybackStateModel(
      id: '${_currentUserId}_${_currentTrack!.id}',
      userId: _currentUserId,
      songId: _currentSongId!,
      trackId: _currentTrack!.id,
      position: position.inMilliseconds,
      updatedAt: DateTime.now(),
    );

    await _playbackStateDataSource.savePlaybackState(state);
  }

  @override
  Future<Duration> loadPlaybackPosition(String trackId) async {
    try {
      final state = await _playbackStateDataSource.getPlaybackState(
        _currentUserId,
        trackId,
      );

      if (state != null) {
        return Duration(milliseconds: state.position);
      }
    } catch (e) {
      // Ignore errors loading position - just start from beginning
    }

    return Duration.zero;
  }

  /// Start periodic auto-save timer
  void _startAutoSaveTimer() {
    _stopAutoSaveTimer(); // Cancel any existing timer
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      savePlaybackPosition();
    });
  }

  /// Stop auto-save timer
  void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// Update the media item shown in the notification
  Future<void> _updateMediaItem() async {
    if (_audioHandler == null || _currentTrack == null) {
      return;
    }

    final mediaItem = MediaItem(
      id: _currentTrack!.id,
      title: _currentTrack!.name,
      artist: 'Repertoire Coach', // Generic artist name
      duration: _player.duration ?? Duration.zero,
      artUri: null, // No album art for now
    );

    await _audioHandler!.updateMediaItem(mediaItem);
  }

  @override
  Future<void> setLoopMode(bool enabled) async {
    _isLooping = enabled;
    await _player.setLoopMode(enabled ? ja.LoopMode.one : ja.LoopMode.off);
  }

  @override
  bool get isLooping => _isLooping;

  @override
  Future<void> setLoopRange(LoopRange? loopRange) async {
    _loopRange = loopRange;

    // Cancel existing loop monitoring
    await _loopSubscription?.cancel();
    _loopSubscription = null;

    // Start monitoring if loop range is set
    if (_loopRange != null) {
      _loopSubscription = _player.positionStream.listen((position) {
        // Check if we've reached or exceeded the loop end position
        if (position >= _loopRange!.endPosition) {
          // Seek back to the start position
          _player.seek(_loopRange!.startPosition);
        }
      });
    }

    _updatePlaybackInfo();
  }

  @override
  LoopRange? get currentLoopRange => _loopRange;

  @override
  bool get isRangeLooping => _loopRange != null;

  @override
  Future<void> dispose() async {
    _stopAutoSaveTimer();
    await _loopSubscription?.cancel();
    await savePlaybackPosition(); // Save one last time before disposing
    await _player.dispose();
    await _playbackController.close();
  }
}

/// Audio handler for background playback
///
/// This class manages the audio service and syncs the just_audio player
/// state with the system media controls and notification.
class _AudioPlayerHandler extends BaseAudioHandler {
  final ja.AudioPlayer _player;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;

  _AudioPlayerHandler(this._player) {
    // Sync player state to audio service
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      final processingState = _mapProcessingState(playerState.processingState);

      playbackState.add(PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        playing: playing,
        processingState: processingState,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  /// Map just_audio processing state to audio_service processing state
  AudioProcessingState _mapProcessingState(ja.ProcessingState state) {
    switch (state) {
      case ja.ProcessingState.idle:
        return AudioProcessingState.idle;
      case ja.ProcessingState.loading:
        return AudioProcessingState.loading;
      case ja.ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ja.ProcessingState.ready:
        return AudioProcessingState.ready;
      case ja.ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Cleanup subscriptions
  Future<void> cleanup() async {
    await _playerStateSubscription?.cancel();
  }
}
