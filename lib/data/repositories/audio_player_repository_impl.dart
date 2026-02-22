import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/loop_range.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_player_repository.dart';
import '../../core/services/error_reporter.dart';
import '../../core/services/r2_signer_client.dart';
import '../../core/services/supabase_service.dart';
import '../datasources/local/database.dart' as db;

/// Implementation of AudioPlayerRepository using just_audio
class AudioPlayerRepositoryImpl implements AudioPlayerRepository {
  final ja.AudioPlayer _player;
  final StreamController<PlaybackInfo> _playbackController;
  final db.AppDatabase _database;
  final SupabaseService _supabaseService;
  AudioHandler? _audioHandler;

  Track? _currentTrack;
  String? _currentSongName;
  String? _currentAlbumName;
  PlaybackInfo _currentPlaybackInfo;
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

  final R2SignerClient _signerClient;

  AudioPlayerRepositoryImpl(this._database, this._supabaseService, this._signerClient)
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
    // Eagerly initialize AudioService so Android Auto can discover the app
    // on startup, before any playback occurs. Safe because the Riverpod
    // provider is created after runApp().
    Future.microtask(() => _ensureInitialized());
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

    final handler = _audioHandler as _AudioPlayerHandler?;
    if (handler != null) {
      // Sync repository state when Android Auto initiates playback.
      // Without this callback, _currentTrack stays null while a track plays
      // from the car display, causing the phone UI to show no active track.
      handler.onTrackLoaded = (trackRow, songTitle, concertName) {
        _currentTrack = Track(
          id: trackRow.id,
          songId: trackRow.songId,
          name: trackRow.name,
          audioUrl: trackRow.audioUrl,
          storagePath: trackRow.storagePath,
          durationMs: trackRow.durationMs,
          filePath: trackRow.filePath,
          createdAt: trackRow.createdAt,
          updatedAt: trackRow.updatedAt,
        );
        _currentSongName = songTitle;
        _currentAlbumName = concertName;
        _updatePlaybackInfo();
      };

      // Notify Android Auto that the browse tree is ready. Auto may have called
      // onLoadChildren() before AudioService.init() completed (cold start via
      // car display) and cached an empty result. Signalling here causes it to
      // re-query, picking up the real favourites list.
      handler.refreshChildren(AudioService.browsableRootId);
    }
  }

  @override
  void notifyFavouritesChanged() {
    (_audioHandler as _AudioPlayerHandler?)?.refreshChildren('favorites');
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
        builder: () => _AudioPlayerHandler(_player, _database, _supabaseService, _signerClient),
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
        // Track finished naturally — pause and keep track info intact so the
        // UI shows "paused" (not "idle").  This lets the play button call
        // resume() instead of playTrack(), avoiding a full audio reload.
        _player.pause();
        _audioHandler?.stop(); // dismiss media notification
      }
      _updatePlaybackInfo();
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
      speed: _player.speed,
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
  Stream<PlaybackInfo> get playbackStream async* {
    // Emit the current state immediately so that late subscribers (e.g.
    // Riverpod StreamProvider) get data without waiting for a player event.
    // A plain broadcast stream would lose all past events.
    yield _currentPlaybackInfo;
    yield* _playbackController.stream;
  }

  @override
  PlaybackInfo get currentPlayback => _currentPlaybackInfo;

  @override
  Future<void> playTrack(
    Track track, {
    String? audioUrl,
    String? songName,
    String? albumName,
  }) async {
    await _ensureInitialized(); // ensure audio_service & audio_session are ready

    // Use provided audioUrl (e.g., signed URL) or fall back to track's stored URL
    final effectiveAudioUrl = audioUrl ?? track.audioUrl;

    // On web, we MUST have a URL - local files don't work
    if (kIsWeb && effectiveAudioUrl == null) {
      final errorInfo = PlaybackInfo.error(
        'Track has no cloud URL. Please upload the audio file to Supabase storage.',
      );
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      throw Exception('Track has no cloud URL (required for web playback)');
    }

    if (effectiveAudioUrl == null && track.filePath == null) {
      final errorInfo = PlaybackInfo.error('Track has no audio file');
      _currentPlaybackInfo = errorInfo;
      _playbackController.add(errorInfo);
      throw Exception('Track has no audio file');
    }

    try {
      _currentTrack = track;
      _currentSongName = songName;
      _currentAlbumName = albumName;

      // Set audio source - prefer provided/cloud URL, fall back to local file
      if (effectiveAudioUrl != null) {
        await _player.setUrl(effectiveAudioUrl);
      } else if (!kIsWeb && track.filePath != null) {
        // Play from local file (only works on mobile/desktop, not web)
        final file = File(track.filePath!);
        if (!await file.exists()) {
          final errorInfo = PlaybackInfo.error('Audio file not found: ${track.filePath}');
          _currentPlaybackInfo = errorInfo;
          _playbackController.add(errorInfo);
          throw Exception('Audio file not found');
        }
        await _player.setFilePath(track.filePath!);
      }

      // Always start from the beginning
      await _player.seek(Duration.zero);

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

    // If we're at or near the end of the track, restart from the beginning.
    final duration = _player.duration ?? Duration.zero;
    final position = _player.position;

    if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 100)) {
      await _player.seek(Duration.zero);
    }

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
    await _player.seek(Duration.zero); // Reset position to prevent leaking to the next track
    // Tell audio_service to stop the foreground service so the notification
    // is dismissed.  Without this the notification lingers after the track
    // finishes, showing a stale play button.  The handler's stop() calls
    // super.stop() which does the actual service teardown.  It also calls
    // _player.stop() again — that second call is a harmless no-op.
    await _audioHandler?.stop();
    _currentTrack = null;
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

  /// Update the media item shown in the notification
  Future<void> _updateMediaItem() async {
    if (_audioHandler == null || _currentTrack == null) {
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

    await _audioHandler!.updateMediaItem(mediaItem);
  }

  @override
  Future<void> setLoopMode(bool enabled) async {
    _isLooping = enabled;
    await _player.setLoopMode(enabled ? ja.LoopMode.one : ja.LoopMode.off);
    _updatePlaybackInfo(); // Broadcast state change to UI
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
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _updatePlaybackInfo();
  }

  @override
  double get speed => _player.speed;

  @override
  Future<void> dispose() async {
    await _loopSubscription?.cancel();
    await _player.dispose();
    await _playbackController.close();
  }
}

/// Audio handler for background playback and Android Auto content browsing
///
/// This class manages the audio service and syncs the just_audio player
/// state with the system media controls and notification. It also exposes
/// the user's favorite tracks for browsing in Android Auto via
/// [getChildren] and supports voice search via [search].
class _AudioPlayerHandler extends BaseAudioHandler {
  final ja.AudioPlayer _player;
  final db.AppDatabase _database;
  final SupabaseService _supabaseService;
  final R2SignerClient _signerClient;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  /// Per-parentMediaId subjects used to signal Android Auto to re-query children.
  final _childrenSubjects = <String, BehaviorSubject<Map<String, dynamic>>>{};

  /// Callback invoked when Android Auto initiates playback so that
  /// [AudioPlayerRepositoryImpl] can sync its own state (_currentTrack etc.).
  /// Parameters: (trackRow, songTitle, concertName)
  void Function(db.Track, String?, String?)? onTrackLoaded;

  /// Android Auto browsable root ID used by audio_service
  static const _favoritesId = 'favorites';

  _AudioPlayerHandler(this._player, this._database, this._supabaseService, this._signerClient) {
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

  // ---------------------------------------------------------------------------
  // Android Auto: content browsing
  // ---------------------------------------------------------------------------

  /// Override subscribeToChildren so Android Auto re-queries when we emit on
  /// the subject.  [BaseAudioHandler] returns a new sealed BehaviorSubject on
  /// every call; by storing our own subjects we can emit to them from outside.
  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return _childrenSubjects.putIfAbsent(
      parentMediaId,
      () => BehaviorSubject.seeded({}),
    );
  }

  /// Emit an event on [parentMediaId]'s subject so the framework calls
  /// [_platform.notifyChildrenChanged], prompting Android Auto to re-query.
  void refreshChildren(String parentMediaId) {
    _childrenSubjects[parentMediaId]?.add({});
  }

  /// Return the current authenticated user ID, or null if not logged in.
  String? get _userId => _supabaseService.client.auth.currentUser?.id;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      if (parentMediaId == AudioService.browsableRootId) {
        // Root level: single "Favorites" browsable folder
        return [
          MediaItem(
            id: _favoritesId,
            title: 'Favorites',
            playable: false,
            extras: const {'browsable': true},
          ),
        ];
      }

      if (parentMediaId == _favoritesId) {
        return await _getFavoriteMediaItems();
      }

      return [];
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace: stackTrace, screen: 'android_auto_browse');
      return [];
    }
  }

  /// Build a list of playable [MediaItem]s from the user's favorite tracks.
  ///
  /// Uses a single 4-way join query (favorites→tracks→songs→concerts) instead
  /// of N+1 sequential lookups, avoiding potential Android Auto browse timeouts
  /// for users with many favourites.
  Future<List<MediaItem>> _getFavoriteMediaItems() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final rows = await _database.getFavoriteTracksWithMeta(userId);
      return rows.map((row) {
        final trackRow = row.track;
        final songRow = row.song;
        final concertRow = row.concert;
        return MediaItem(
          id: trackRow.id,
          title: songRow != null
              ? '${songRow.title} – ${trackRow.name}'
              : trackRow.name,
          album: concertRow?.name,
          duration: trackRow.durationMs != null
              ? Duration(milliseconds: trackRow.durationMs!)
              : null,
          playable: true,
        );
      }).toList();
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace: stackTrace, screen: 'android_auto_favorites');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Android Auto: play from browse / queue
  // ---------------------------------------------------------------------------

  Future<void> _playTrackById(
    String trackId, {
    MediaItem? preferredItem,
    bool autoPlay = true,
  }) async {
    // Look up the Track from the local Drift database
    final trackRow = await _database.getTrackById(trackId);
    if (trackRow == null) return;

    // Look up song and concert for display metadata and repository sync
    final songRow = await _database.getSongById(trackRow.songId);
    String? concertName;
    if (songRow != null) {
      final concertRow = await _database.getConcertById(songRow.concertId);
      concertName = concertRow?.name;
    }

    // Fetch a short-lived presigned R2 URL for playback
    String? signedUrl;
    if (trackRow.storagePath != null) {
      try {
        signedUrl = await _signerClient.getPlayUrl(trackRow.id);
      } catch (_) {
        // Fall back to local file if available
      }
    }

    final effectiveUrl = signedUrl;
    if (effectiveUrl != null) {
      await _player.setUrl(effectiveUrl);
    } else if (trackRow.filePath != null) {
      await _player.setFilePath(trackRow.filePath!);
    } else {
      return; // No audio source available
    }

    final item = preferredItem ??
        MediaItem(
          id: trackRow.id,
          title: songRow != null
              ? '${songRow.title} – ${trackRow.name}'
              : trackRow.name,
          album: concertName,
          duration: trackRow.durationMs != null
              ? Duration(milliseconds: trackRow.durationMs!)
              : null,
          playable: true,
        );

    // Update the notification metadata
    mediaItem.add(item);

    // Sync AudioPlayerRepositoryImpl state so the phone UI reflects the
    // track that Android Auto started. Without this, _currentTrack stays
    // null and the phone shows no active track.
    onTrackLoaded?.call(trackRow, songRow?.title, concertName);

    await _player.seek(Duration.zero);
    if (autoPlay) {
      await _player.play();
    }
    _broadcastState();
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    await _playTrackById(item.id, preferredItem: item);
  }

  @override
  Future<void> playFromMediaId(String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    await _playTrackById(mediaId);
  }

  @override
  Future<void> prepareFromMediaId(String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    await _playTrackById(mediaId, autoPlay: false);
  }

  // ---------------------------------------------------------------------------
  // Android Auto: voice search
  // ---------------------------------------------------------------------------

  @override
  Future<List<MediaItem>> search(String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final userId = _userId;
    if (userId == null || query.isEmpty) return [];

    final allFavorites = await _getFavoriteMediaItems();
    final lowerQuery = query.toLowerCase();

    return allFavorites.where((item) {
      return item.title.toLowerCase().contains(lowerQuery) ||
          (item.album?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  @override
  Future<void> playFromSearch(String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final results = await search(query, extras);
    if (results.isNotEmpty) {
      await playMediaItem(results.first);
    }
  }

  // ---------------------------------------------------------------------------
  // Notification & media session state
  // ---------------------------------------------------------------------------

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    // Directly set mediaItem — super.updateMediaItem() in audio_service 0.18.17
    // doesn't actually update the BehaviorSubject (mediaItem.value stays null).
    // Setting it directly ensures the platform listener receives the update.
    mediaItem.add(item);
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

  /// Cleanup subscriptions and subjects
  Future<void> cleanup() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    for (final subject in _childrenSubjects.values) {
      await subject.close();
    }
    _childrenSubjects.clear();
  }
}
