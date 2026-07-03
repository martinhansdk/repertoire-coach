import '../../data/datasources/local/local_choir_data_source.dart';
import '../../data/datasources/local/local_concert_data_source.dart';
import '../../data/datasources/local/local_favorite_track_data_source.dart';
import '../../data/datasources/local/local_marker_data_source.dart';
import '../../data/datasources/local/local_song_data_source.dart';
import '../../data/datasources/local/local_track_data_source.dart';
import '../../data/datasources/remote/remote_choir_data_source.dart';
import '../../data/datasources/remote/remote_concert_data_source.dart';
import '../../data/datasources/remote/remote_favorite_track_data_source.dart';
import '../../data/datasources/remote/remote_marker_data_source.dart';
import '../../data/datasources/remote/remote_song_data_source.dart';
import '../../data/datasources/remote/remote_track_data_source.dart';
import '../sync/adapters/choir_member_sync_adapter.dart';
import '../sync/adapters/choir_sync_adapter.dart';
import '../sync/adapters/concert_sync_adapter.dart';
import '../sync/adapters/favorite_track_sync_adapter.dart';
import '../sync/adapters/marker_set_sync_adapter.dart';
import '../sync/adapters/song_sync_adapter.dart';
import '../sync/adapters/track_sync_adapter.dart';
import '../sync/sync_algorithm.dart';

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
/// Uses generic bidirectional sync algorithm with "newest change wins" strategy.
///
/// Entity sync order (respecting foreign keys):
/// 1. choirs (bidirectional)
/// 2. choir_members (bidirectional)
/// 3. concerts (bidirectional)
/// 4. songs (bidirectional)
/// 5. tracks (bidirectional)
/// 6. marker_sets (bidirectional)
/// 7. favorites (bidirectional)
class SyncService {
  final LocalChoirDataSource _localChoirDataSource;
  final LocalConcertDataSource _localConcertDataSource;
  final LocalSongDataSource _localSongDataSource;
  final LocalTrackDataSource _localTrackDataSource;
  final LocalMarkerDataSource _localMarkerDataSource;
  final LocalFavoriteTrackDataSource _localFavoriteTrackDataSource;

  final RemoteChoirDataSource _remoteChoirDataSource;
  final RemoteConcertDataSource _remoteConcertDataSource;
  final RemoteSongDataSource _remoteSongDataSource;
  final RemoteTrackDataSource _remoteTrackDataSource;
  final RemoteMarkerDataSource _remoteMarkerDataSource;
  final RemoteFavoriteTrackDataSource _remoteFavoriteTrackDataSource;

  SyncService({
    required LocalChoirDataSource localChoirDataSource,
    required LocalConcertDataSource localConcertDataSource,
    required LocalSongDataSource localSongDataSource,
    required LocalTrackDataSource localTrackDataSource,
    required LocalMarkerDataSource localMarkerDataSource,
    required LocalFavoriteTrackDataSource localFavoriteTrackDataSource,
    required RemoteChoirDataSource remoteChoirDataSource,
    required RemoteConcertDataSource remoteConcertDataSource,
    required RemoteSongDataSource remoteSongDataSource,
    required RemoteTrackDataSource remoteTrackDataSource,
    required RemoteMarkerDataSource remoteMarkerDataSource,
    required RemoteFavoriteTrackDataSource remoteFavoriteTrackDataSource,
  })  : _localChoirDataSource = localChoirDataSource,
        _localConcertDataSource = localConcertDataSource,
        _localSongDataSource = localSongDataSource,
        _localTrackDataSource = localTrackDataSource,
        _localMarkerDataSource = localMarkerDataSource,
        _localFavoriteTrackDataSource = localFavoriteTrackDataSource,
        _remoteChoirDataSource = remoteChoirDataSource,
        _remoteConcertDataSource = remoteConcertDataSource,
        _remoteSongDataSource = remoteSongDataSource,
        _remoteTrackDataSource = remoteTrackDataSource,
        _remoteMarkerDataSource = remoteMarkerDataSource,
        _remoteFavoriteTrackDataSource = remoteFavoriteTrackDataSource;

  /// Synchronize data between local and remote
  ///
  /// Uses generic sync algorithm for all entity types.
  /// Bidirectional sync with "newest change wins" strategy.
  ///
  /// [userId] - The authenticated user's ID
  /// [onProgress] - Optional callback for progress updates
  Future<void> syncFromRemote(
    String userId, {
    void Function(SyncState state)? onProgress,
  }) async {
    final steps = [
      ('choirs', ChoirSyncAdapter(_localChoirDataSource, _remoteChoirDataSource, userId)),
      ('choir_members', ChoirMemberSyncAdapter(_localChoirDataSource, _remoteChoirDataSource, userId)),
      ('concerts', ConcertSyncAdapter(_localConcertDataSource, _remoteConcertDataSource, userId)),
      ('songs', SongSyncAdapter(_localSongDataSource, _remoteSongDataSource, userId)),
      ('tracks', TrackSyncAdapter(_localTrackDataSource, _remoteTrackDataSource, userId)),
      ('marker_sets', MarkerSetSyncAdapter(_localMarkerDataSource, _remoteMarkerDataSource, userId)),
      ('favorites', FavoriteTrackSyncAdapter(_localFavoriteTrackDataSource, _remoteFavoriteTrackDataSource, userId)),
    ];

    try {
      var pushFailures = 0;
      for (var i = 0; i < steps.length; i++) {
        final (entityName, adapter) = steps[i];

        onProgress?.call(SyncState.syncing(
          currentEntity: entityName,
          progress: i / steps.length,
        ));

        final result = await SyncAlgorithm(adapter).sync();
        pushFailures += result.pushFailures;
      }

      // Per-item push failures don't abort the sync, but silently reporting
      // success hid items that were stuck unsynced forever (e.g. rejected by a
      // remote CHECK constraint). Surface them so the user can tell.
      onProgress?.call(SyncState.success(
        message: pushFailures == 0
            ? 'Sync complete'
            : 'Sync complete — $pushFailures change(s) could not be uploaded '
                'and will be retried',
      ));
    } catch (e) {
      onProgress?.call(SyncState.error('Sync failed: $e'));
      rethrow;
    }
  }
}
