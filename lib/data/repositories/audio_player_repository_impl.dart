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
import '../../core/services/error_reporter.dart';
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
  String? _currentSongName;
  String? _currentAlbumName;
  PlaybackInfo _currentPlaybackInfo;
  Timer? _autoSaveTimer;
  bool _isLooping = false;
  LoopRange? _loopRange;
  StreamSubscription<Duration>? _loopSubscription;

  /// Lazily-initialised future: created on the first playback call, not in
  /// the constructor.  AudioService.init() requires the Android Activity /
  /// FlutterEngine to be fully ready, which is not guaranteed when Riverpod
  /// creates the provider (often before the widget tree is built).
  Future<void>? _initFuture;

  /// Returns (and caches) the init future.  Idempotent — subsequent calls
  /// return the same future without re-running initialisation.
  Future<void> _ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  AudioPlayerRepositoryImpl(this._playbackStateDataSource)
      : _player = ja.AudioPlayer(
          // Explicitly disable audio offload.  just_audio 0.10.5 defaults to
          // disabled, but be explicit: offload hands the DSP off to a
          // hardware processor that loses contact with the Flutter engine
          // when the CPU sleeps (screen lock), killing playback after ~60 s.
          androidAudioOffloadPreferences: const ja.AndroidAudioOffloadPreferences(
            audioOffloadMode: ja.AndroidAudioOffloadMode.disabled,
          ),
        ),
        _playbackController = StreamController<PlaybackInfo>.broadcast(),
        _currentPlaybackInfo = const PlaybackInfo.idle() {
    _initializePlayerListeners();
  }

  /// audio_service MUST be initialised before audio_session is configured.
  /// audio_session docs state: "configure after audio_service is init'd".
  /// Running them in parallel (Future.wait) was a race that left the
  /// MediaSession unaware of the audio focus configuration.
  /// Neither future rejects: each wraps its own errors so that a failure
  /// in one (e.g. desktop platform with no audio service) does not prevent
  /// the other from completing.
  Future<void> _initialize() async {
    await _initializeAudioService();
    await _configureAudioSession();
  }

  /// Configure audio session for background playback
  Future<void> _configureAudioSession() async {
    try {
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
    } catch (e, stackTrace) {
      // audio_session may not be available on all platforms; continue without it.
      ErrorReporter.report(e, stackTrace: stackTrace, screen: 'audio_session_init');
    }
  }

  /// Initialize audio service for background playback with media notifications
  Future<void> _initializeAudioService() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => _AudioPlayerHandler(_player),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.repertoire_coach.audio',
          androidNotificationChannelName: 'Repertoire Coach Audio',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          // androidNotificationOngoing: true requires this to be true;
          // the assertion !androidNotificationOngoing || androidStopForegroundOnPause
          // would otherwise fire inside AudioService.init().
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e, stackTrace) {
      // If audio service fails to initialize (e.g., on desktop platforms),
      // continue without it. Background playback will still work on iOS/Android
      // via audio_session configuration alone.
      // NOTE: On Android this MUST succeed — if it fails, there will be no
      // foreground service, no lock-screen controls, and the system will
      // kill the app after a short idle period.
      ErrorReporter.report(e, stackTrace: stackTrace, screen: 'audio_service_init');
    }
  }

  /// Initialize listeners for the just_audio player
  void _initializePlayerListeners() {
    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ja.ProcessingState.completed &&
          !_isLooping) {
        // Track finished without loop — stop and clear state
        stop();
      } else {
        _updatePlaybackInfo();
      }
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      _updatePlaybackInfo();
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      _updatePlaybackInfo();
      _updateMediaItem(); // refresh notification with actual duration
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
      isTrackLooping: _isLooping,
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
  Future<void> playTrack(Track track, {Duration startPosition = Duration.zero, String? audioUrl, String? songName, String? albumName}) async {
    await _ensureInitialized(); // ensure audio_service & audio_session are ready

    // Use provided audioUrl (e.g., signed URL) or fall back to track's stored URL
    final effectiveAudioUrl = audioUrl ?? track.audioUrl;

    if (effectiveAudioUrl == null && track.filePath == null) {
      final errorInfo = PlaybackInfo.error('Track has no audio file');
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      throw Exception('Track has no audio file');
    }

    try {
      _currentTrack = track;
      _currentSongId = track.songId;
      _currentSongName = songName;
      _currentAlbumName = albumName;

      // Set audio source - prefer provided/cloud URL, fall back to local file
      if (effectiveAudioUrl != null) {
        await _player.setUrl(effectiveAudioUrl);
      } else if (track.filePath != null) {
        // Play from local file
        final file = File(track.filePath!);
        if (!await file.exists()) {
          final errorInfo = PlaybackInfo.error('Audio file not found: ${track.filePath}');
          _currentPlaybackInfo = errorInfo;
          _playbackController.add(errorInfo);
          throw Exception('Audio file not found');
        }
        await _player.setFilePath(track.filePath!);
      }

      // Load saved position if no start position specified
      Duration seekPosition = startPosition;
      if (startPosition == Duration.zero) {
        seekPosition = await loadPlaybackPosition(track.id);
      }

      // If the saved position is at or past the end of the track the previous
      // session finished playing it — start from the beginning instead of
      // immediately hitting ProcessingState.completed again.
      if (_player.duration != null && seekPosition >= _player.duration!) {
        seekPosition = Duration.zero;
      }

      // Seek to position if needed
      if (seekPosition > Duration.zero) {
        await _player.seek(seekPosition);
      }

      // Set the MediaItem before play() so the notification has a title.
      await _updateMediaItem();

      // Start playback
      await _player.play();

      // On Android play() triggers startForeground(), which posts the
      // notification.  The MediaItem set above travels over a separate
      // platform channel; if the notification is posted before that call
      // lands the lock-screen control shows song=null / artist=null.
      // A second update after play() guarantees the MediaSession is
      // populated once the notification becomes visible.
      await _updateMediaItem();

      // Start auto-save timer (save position every 5 seconds while playing)
      _startAutoSaveTimer();

      _updatePlaybackInfo();
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace: stackTrace, screen: 'audio_player');
      final errorInfo = PlaybackInfo.error('Failed to play track: $e');
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    await _ensureInitialized(); // ensure audio_service & audio_session are ready

    if (_player.playerState.processingState == ja.ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
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
    // Tell audio_service to stop the foreground service so the notification
    // is dismissed.  Without this the notification lingers after the track
    // finishes, showing a stale play button.  The handler's stop() calls
    // super.stop() which does the actual service teardown.  It also calls
    // _player.stop() again — that second call is a harmless no-op.
    await _audioHandler?.stop();
    _currentTrack = null;
    _currentSongId = null;
    _currentSongName = null;
    _currentAlbumName = null;
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
      // ignore: avoid_print
      print('DEBUG _updateMediaItem: skipped (_audioHandler=${_audioHandler != null}, _currentTrack=${_currentTrack != null})');
      return;
    }

    final mediaItem = MediaItem(
      id: _currentTrack!.id,
      title: _currentSongName ?? _currentTrack!.name, // Song name, fallback to track name
      artist: _currentTrack!.name, // Track name (voice part: Soprano, Alto, etc.)
      album: _currentAlbumName, // Concert name
      duration: _player.duration ?? Duration.zero,
      artUri: null, // No album art for now
    );

    // ignore: avoid_print
    print('DEBUG _updateMediaItem: calling updateMediaItem with title="${mediaItem.title}", artist="${mediaItem.artist}", duration=${mediaItem.duration}');
    await _audioHandler!.updateMediaItem(mediaItem);
    // ignore: avoid_print
    print('DEBUG _updateMediaItem: updateMediaItem returned');
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
  StreamSubscription<Duration>? _positionSubscription;

  _AudioPlayerHandler(this._player) {
    // Sync player state to audio service whenever just_audio fires a state event.
    _playerStateSubscription = _player.playerStateStream.listen((_) {
      _broadcastState();
    });
    // Sync position so the notification progress bar updates continuously.
    // audio_service extrapolates position from updatePosition + elapsed time,
    // but periodic corrections prevent drift.
    _positionSubscription = _player.positionStream.listen((_) {
      _broadcastState();
    });
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    // ignore: avoid_print
    print('DEBUG _AudioPlayerHandler.updateMediaItem: received title="${item.title}", artist="${item.artist}"');
    // Directly set mediaItem — super.updateMediaItem() in audio_service 0.18.17
    // doesn't actually update the BehaviorSubject (mediaItem.value stays null).
    // Setting it directly ensures the platform listener receives the update.
    mediaItem.add(item);
    // ignore: avoid_print
    print('DEBUG _AudioPlayerHandler.updateMediaItem: after mediaItem.add(), value=${mediaItem.value?.title}');
    await super.updateMediaItem(item);
  }

  /// Push the current player state to the audio_service notification.
  /// Called automatically on every playerStateStream event, and explicitly
  /// after rewind/fastForward so the notification progress bar jumps
  /// immediately (playerStateStream doesn't fire on a seek-only event).
  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.rewind,
        MediaAction.fastForward,
      },
      playing: playing,
      processingState: _mapProcessingState(_player.playerState.processingState),
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
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
  Future<void> play() async {
    await _player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> rewind() async {
    final currentPosition = _player.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    await _player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
    _broadcastState();
  }

  @override
  Future<void> fastForward() async {
    final currentPosition = _player.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final duration = _player.duration;
    if (duration != null && newPosition > duration) {
      await _player.seek(duration);
    } else {
      await _player.seek(newPosition);
    }
    _broadcastState();
  }

  /// Cleanup subscriptions
  Future<void> cleanup() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
  }
}
