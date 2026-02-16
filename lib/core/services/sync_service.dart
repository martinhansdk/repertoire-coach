import '../../data/datasources/local/local_choir_data_source.dart';
import '../../data/datasources/local/local_concert_data_source.dart';
import '../../data/datasources/local/local_marker_data_source.dart';
import '../../data/datasources/local/local_song_data_source.dart';
import '../../data/datasources/local/local_track_data_source.dart';
import '../../data/datasources/local/local_user_playback_state_data_source.dart';
import '../../data/datasources/remote/remote_choir_data_source.dart';
import '../../data/datasources/remote/remote_concert_data_source.dart';
import '../../data/datasources/remote/remote_marker_data_source.dart';
import '../../data/datasources/remote/remote_song_data_source.dart';
import '../../data/datasources/remote/remote_track_data_source.dart';
import '../../data/datasources/remote/remote_user_playback_state_data_source.dart';

/// Status of a sync operation
enum SyncStatus {
  /// No sync in progress
  idle,

  /// Sync is currently running
  syncing,

  /// Sync completed successfully
  success,

  /// Sync failed with an error
  error,
}

/// State of a sync operation
class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;
  final String? currentEntity;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.progress,
    this.currentEntity,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    double? progress,
    String? currentEntity,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      currentEntity: currentEntity ?? this.currentEntity,
    );
  }

  /// Initial idle state
  static const initial = SyncState(status: SyncStatus.idle);

  /// Starting sync state
  factory SyncState.syncing({String? currentEntity, double? progress}) {
    return SyncState(
      status: SyncStatus.syncing,
      currentEntity: currentEntity,
      progress: progress,
    );
  }

  /// Successful sync state
  factory SyncState.success({String? message}) {
    return SyncState(
      status: SyncStatus.success,
      message: message,
      progress: 1.0,
    );
  }

  /// Error sync state
  factory SyncState.error(String message) {
    return SyncState(
      status: SyncStatus.error,
      message: message,
    );
  }
}

/// Service for synchronizing data between local Drift database and remote Supabase
///
/// Handles pulling data from Supabase into the local database on login.
/// Respects foreign key dependencies by syncing entities in the correct order.
///
/// Entity sync order (respecting foreign keys):
/// 1. choirs (no FK dependencies)
/// 2. choir_members (depends on choirs, users)
/// 3. concerts (depends on choirs)
/// 4. songs (depends on concerts)
/// 5. tracks (depends on songs)
/// 6. marker_sets (depends on tracks, users)
/// 7. markers (depends on marker_sets)
/// 8. playback_states (depends on songs, tracks, users)
class SyncService {
  final LocalChoirDataSource _localChoirDataSource;
  final LocalConcertDataSource _localConcertDataSource;
  final LocalSongDataSource _localSongDataSource;
  final LocalTrackDataSource _localTrackDataSource;
  final LocalMarkerDataSource _localMarkerDataSource;
  final LocalUserPlaybackStateDataSource _localPlaybackStateDataSource;

  final RemoteChoirDataSource _remoteChoirDataSource;
  final RemoteConcertDataSource _remoteConcertDataSource;
  final RemoteSongDataSource _remoteSongDataSource;
  final RemoteTrackDataSource _remoteTrackDataSource;
  final RemoteMarkerDataSource _remoteMarkerDataSource;
  final RemoteUserPlaybackStateDataSource _remotePlaybackStateDataSource;

  SyncService({
    required LocalChoirDataSource localChoirDataSource,
    required LocalConcertDataSource localConcertDataSource,
    required LocalSongDataSource localSongDataSource,
    required LocalTrackDataSource localTrackDataSource,
    required LocalMarkerDataSource localMarkerDataSource,
    required LocalUserPlaybackStateDataSource localPlaybackStateDataSource,
    required RemoteChoirDataSource remoteChoirDataSource,
    required RemoteConcertDataSource remoteConcertDataSource,
    required RemoteSongDataSource remoteSongDataSource,
    required RemoteTrackDataSource remoteTrackDataSource,
    required RemoteMarkerDataSource remoteMarkerDataSource,
    required RemoteUserPlaybackStateDataSource remotePlaybackStateDataSource,
  })  : _localChoirDataSource = localChoirDataSource,
        _localConcertDataSource = localConcertDataSource,
        _localSongDataSource = localSongDataSource,
        _localTrackDataSource = localTrackDataSource,
        _localMarkerDataSource = localMarkerDataSource,
        _localPlaybackStateDataSource = localPlaybackStateDataSource,
        _remoteChoirDataSource = remoteChoirDataSource,
        _remoteConcertDataSource = remoteConcertDataSource,
        _remoteSongDataSource = remoteSongDataSource,
        _remoteTrackDataSource = remoteTrackDataSource,
        _remoteMarkerDataSource = remoteMarkerDataSource,
        _remotePlaybackStateDataSource = remotePlaybackStateDataSource;

  /// Synchronize data from remote Supabase to local database
  ///
  /// Pulls all data accessible to the user from Supabase and upserts
  /// it into the local Drift database. This is the main sync entry point
  /// called after user authentication.
  ///
  /// [userId] - The authenticated user's ID
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Throws an exception if sync fails.
  Future<void> syncFromRemote(
    String userId, {
    void Function(SyncState state)? onProgress,
  }) async {
    try {
      // Step 1: Sync choirs and choir members (8 total steps)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'choirs',
        progress: 0.0,
      ));
      await _syncChoirs(userId);

      // Step 2: Sync concerts
      onProgress?.call(SyncState.syncing(
        currentEntity: 'concerts',
        progress: 1 / 8,
      ));
      await _syncConcerts(userId);

      // Step 3: Sync songs
      onProgress?.call(SyncState.syncing(
        currentEntity: 'songs',
        progress: 2 / 8,
      ));
      await _syncSongs(userId);

      // Step 4: Sync tracks
      onProgress?.call(SyncState.syncing(
        currentEntity: 'tracks',
        progress: 3 / 8,
      ));
      await _syncTracks(userId);

      // Step 5: Sync marker sets
      onProgress?.call(SyncState.syncing(
        currentEntity: 'marker_sets',
        progress: 4 / 8,
      ));
      await _syncMarkerSets(userId);

      // Step 6: Sync markers
      onProgress?.call(SyncState.syncing(
        currentEntity: 'markers',
        progress: 5 / 8,
      ));
      await _syncMarkers(userId);

      // Step 7: Sync playback states
      onProgress?.call(SyncState.syncing(
        currentEntity: 'playback_states',
        progress: 6 / 8,
      ));
      await _syncPlaybackStates(userId);

      // Done
      onProgress?.call(SyncState.success(message: 'Sync complete'));
    } catch (e) {
      onProgress?.call(SyncState.error('Sync failed: $e'));
      rethrow;
    }
  }

  /// Sync choirs and choir members from remote to local
  Future<void> _syncChoirs(String userId) async {
    // Fetch choirs from remote
    final remoteChoirs = await _remoteChoirDataSource.getChoirs(userId);

    // Upsert each choir to local (mark as synced since coming from remote)
    for (final choir in remoteChoirs) {
      await _localChoirDataSource.upsertChoir(
        choir,
        markForSync: false, // Already in sync with remote
      );
    }

    // Sync choir members for each choir
    final allMembers = await _remoteChoirDataSource.getChoirMembersForUser(userId);
    for (final member in allMembers) {
      await _localChoirDataSource.upsertMember(
        member,
        markForSync: false,
      );
    }
  }

  /// Sync concerts from remote to local
  Future<void> _syncConcerts(String userId) async {
    final remoteConcerts = await _remoteConcertDataSource.getConcerts(userId);

    for (final concert in remoteConcerts) {
      await _localConcertDataSource.upsertConcert(
        concert,
        markForSync: false,
      );
    }
  }

  /// Sync songs from remote to local
  Future<void> _syncSongs(String userId) async {
    // Get all songs for all concerts the user has access to
    final remoteSongs = await _remoteSongDataSource.getSongsForUser(userId);

    for (final song in remoteSongs) {
      await _localSongDataSource.upsertSong(
        song,
        markForSync: false,
      );
    }
  }

  /// Sync tracks from remote to local
  Future<void> _syncTracks(String userId) async {
    // Get all tracks for all songs the user has access to
    final remoteTracks = await _remoteTrackDataSource.getTracksForUser(userId);

    for (final track in remoteTracks) {
      await _localTrackDataSource.upsertTrack(
        track,
        markForSync: false,
      );
    }

    // Remove local tracks that were deleted on remote
    final remoteTrackIds = remoteTracks.map((t) => t.id).toSet();
    await _localTrackDataSource.hardDeleteTracksNotIn(remoteTrackIds);
  }

  /// Sync marker sets from remote to local
  Future<void> _syncMarkerSets(String userId) async {
    // Get all marker sets for the user
    final remoteMarkerSets =
        await _remoteMarkerDataSource.getMarkerSetsForUser(userId);

    for (final markerSet in remoteMarkerSets) {
      await _localMarkerDataSource.upsertMarkerSet(
        markerSet,
        markForSync: false,
      );
    }
  }

  /// Sync markers from remote to local
  Future<void> _syncMarkers(String userId) async {
    // Get all markers for the user
    final remoteMarkers =
        await _remoteMarkerDataSource.getMarkersForUser(userId);

    for (final marker in remoteMarkers) {
      await _localMarkerDataSource.upsertMarker(
        marker,
        markForSync: false,
      );
    }
  }

  /// Sync playback states from remote to local
  Future<void> _syncPlaybackStates(String userId) async {
    // Get all playback states for the user
    final remoteStates =
        await _remotePlaybackStateDataSource.getPlaybackStatesForUser(userId);

    for (final state in remoteStates) {
      await _localPlaybackStateDataSource.savePlaybackState(state);
    }
  }
}
