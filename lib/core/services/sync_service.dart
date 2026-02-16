import '../../data/datasources/local/local_choir_data_source.dart';
import '../../data/datasources/local/local_concert_data_source.dart';
import '../../data/datasources/local/local_favorite_track_data_source.dart';
import '../../data/datasources/local/local_marker_data_source.dart';
import '../../data/datasources/local/local_song_data_source.dart';
import '../../data/datasources/local/local_track_data_source.dart';
import '../../data/datasources/local/local_user_playback_state_data_source.dart';
import '../../data/datasources/remote/remote_choir_data_source.dart';
import '../../data/datasources/remote/remote_concert_data_source.dart';
import '../../data/datasources/remote/remote_favorite_track_data_source.dart';
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
/// Uses "newest change wins" bidirectional sync:
/// 1. Push unsynced local changes to remote (only when local is newer)
/// 2. Pull remote changes to local (skip items just pushed)
/// 3. Clean up synced local items not present on remote
///
/// Entity sync order (respecting foreign keys):
/// 1. choirs (pull-only, read-only for regular users)
/// 2. choir_members (pull-only)
/// 3. concerts (bidirectional)
/// 4. songs (bidirectional)
/// 5. tracks (bidirectional)
/// 6. marker_sets (bidirectional)
/// 7. markers (bidirectional)
/// 8. favorites (bidirectional)
/// 9. playback_states (pull-only)
class SyncService {
  final LocalChoirDataSource _localChoirDataSource;
  final LocalConcertDataSource _localConcertDataSource;
  final LocalSongDataSource _localSongDataSource;
  final LocalTrackDataSource _localTrackDataSource;
  final LocalMarkerDataSource _localMarkerDataSource;
  final LocalUserPlaybackStateDataSource _localPlaybackStateDataSource;
  final LocalFavoriteTrackDataSource _localFavoriteTrackDataSource;

  final RemoteChoirDataSource _remoteChoirDataSource;
  final RemoteConcertDataSource _remoteConcertDataSource;
  final RemoteSongDataSource _remoteSongDataSource;
  final RemoteTrackDataSource _remoteTrackDataSource;
  final RemoteMarkerDataSource _remoteMarkerDataSource;
  final RemoteUserPlaybackStateDataSource _remotePlaybackStateDataSource;
  final RemoteFavoriteTrackDataSource _remoteFavoriteTrackDataSource;

  SyncService({
    required LocalChoirDataSource localChoirDataSource,
    required LocalConcertDataSource localConcertDataSource,
    required LocalSongDataSource localSongDataSource,
    required LocalTrackDataSource localTrackDataSource,
    required LocalMarkerDataSource localMarkerDataSource,
    required LocalUserPlaybackStateDataSource localPlaybackStateDataSource,
    required LocalFavoriteTrackDataSource localFavoriteTrackDataSource,
    required RemoteChoirDataSource remoteChoirDataSource,
    required RemoteConcertDataSource remoteConcertDataSource,
    required RemoteSongDataSource remoteSongDataSource,
    required RemoteTrackDataSource remoteTrackDataSource,
    required RemoteMarkerDataSource remoteMarkerDataSource,
    required RemoteUserPlaybackStateDataSource remotePlaybackStateDataSource,
    required RemoteFavoriteTrackDataSource remoteFavoriteTrackDataSource,
  })  : _localChoirDataSource = localChoirDataSource,
        _localConcertDataSource = localConcertDataSource,
        _localSongDataSource = localSongDataSource,
        _localTrackDataSource = localTrackDataSource,
        _localMarkerDataSource = localMarkerDataSource,
        _localPlaybackStateDataSource = localPlaybackStateDataSource,
        _localFavoriteTrackDataSource = localFavoriteTrackDataSource,
        _remoteChoirDataSource = remoteChoirDataSource,
        _remoteConcertDataSource = remoteConcertDataSource,
        _remoteSongDataSource = remoteSongDataSource,
        _remoteTrackDataSource = remoteTrackDataSource,
        _remoteMarkerDataSource = remoteMarkerDataSource,
        _remotePlaybackStateDataSource = remotePlaybackStateDataSource,
        _remoteFavoriteTrackDataSource = remoteFavoriteTrackDataSource;

  /// Synchronize data between local and remote
  ///
  /// Bidirectional sync using "newest change wins" strategy.
  /// Pushes unsynced local changes first, then pulls remote changes.
  ///
  /// [userId] - The authenticated user's ID
  /// [onProgress] - Optional callback for progress updates
  Future<void> syncFromRemote(
    String userId, {
    void Function(SyncState state)? onProgress,
  }) async {
    const totalSteps = 9;
    try {
      // Step 1: Sync choirs (pull-only)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'choirs',
        progress: 0.0,
      ));
      await _syncChoirs(userId);

      // Step 2: Sync concerts (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'concerts',
        progress: 1 / totalSteps,
      ));
      await _syncConcerts(userId);

      // Step 3: Sync songs (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'songs',
        progress: 2 / totalSteps,
      ));
      await _syncSongs(userId);

      // Step 4: Sync tracks (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'tracks',
        progress: 3 / totalSteps,
      ));
      await _syncTracks(userId);

      // Step 5: Sync marker sets (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'marker_sets',
        progress: 4 / totalSteps,
      ));
      await _syncMarkerSets(userId);

      // Step 6: Sync markers (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'markers',
        progress: 5 / totalSteps,
      ));
      await _syncMarkers(userId);

      // Step 7: Sync favorites (bidirectional)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'favorites',
        progress: 6 / totalSteps,
      ));
      await _syncFavorites(userId);

      // Step 8: Sync playback states (pull-only)
      onProgress?.call(SyncState.syncing(
        currentEntity: 'playback_states',
        progress: 7 / totalSteps,
      ));
      await _syncPlaybackStates(userId);

      // Done
      onProgress?.call(SyncState.success(message: 'Sync complete'));
    } catch (e) {
      onProgress?.call(SyncState.error('Sync failed: $e'));
      rethrow;
    }
  }

  /// Sync choirs and choir members from remote to local (pull-only)
  Future<void> _syncChoirs(String userId) async {
    final remoteChoirs = await _remoteChoirDataSource.getChoirs(userId);

    for (final choir in remoteChoirs) {
      await _localChoirDataSource.upsertChoir(
        choir,
        markForSync: false,
      );
    }

    final allMembers =
        await _remoteChoirDataSource.getChoirMembersForUser(userId);
    for (final member in allMembers) {
      await _localChoirDataSource.upsertMember(
        member,
        markForSync: false,
      );
    }
  }

  /// Sync concerts with push-before-pull
  Future<void> _syncConcerts(String userId) async {
    // 1. Get unsynced local concerts
    final localUnsynced = await _localConcertDataSource.getUnsyncedConcerts();

    // 2. Get all remote concerts
    final remoteConcerts = await _remoteConcertDataSource.getConcerts(userId);
    final remoteMap = {for (final c in remoteConcerts) c.id: c};
    final pushedIds = <String>{};

    // 3. Push phase: only push if local is newer
    for (final local in localUnsynced) {
      final remote = remoteMap[local.id];

      if (remote == null) {
        // New local creation - push to remote
        try {
          await _remoteConcertDataSource.createConcert(local);
        } catch (_) {
          // Ignore push failures - will retry next sync
          continue;
        }
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        // Local is newer - push update
        try {
          await _remoteConcertDataSource.updateConcert(local);
        } catch (_) {
          continue;
        }
      }
      // else: remote is newer, skip push
      await _localConcertDataSource.markAsSynced(local.id);
      pushedIds.add(local.id);
    }

    // 4. Pull phase: skip items we just pushed
    for (final remote in remoteConcerts) {
      if (!pushedIds.contains(remote.id)) {
        await _localConcertDataSource.upsertConcert(
          remote,
          markForSync: false,
        );
      }
    }

    // 5. Cleanup: hard-delete synced local concerts not in remote
    final remoteIds = remoteConcerts.map((c) => c.id).toSet();
    await _localConcertDataSource.hardDeleteConcertsNotIn(remoteIds);
  }

  /// Sync songs with push-before-pull
  Future<void> _syncSongs(String userId) async {
    final localUnsynced = await _localSongDataSource.getUnsyncedSongs();
    final remoteSongs = await _remoteSongDataSource.getSongsForUser(userId);
    final remoteMap = {for (final s in remoteSongs) s.id: s};
    final pushedIds = <String>{};

    for (final local in localUnsynced) {
      final remote = remoteMap[local.id];

      if (remote == null) {
        try {
          await _remoteSongDataSource.createSong(local);
        } catch (_) {
          continue;
        }
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        try {
          await _remoteSongDataSource.updateSong(local);
        } catch (_) {
          continue;
        }
      }
      await _localSongDataSource.markAsSynced(local.id);
      pushedIds.add(local.id);
    }

    for (final remote in remoteSongs) {
      if (!pushedIds.contains(remote.id)) {
        await _localSongDataSource.upsertSong(
          remote,
          markForSync: false,
        );
      }
    }

    final remoteIds = remoteSongs.map((s) => s.id).toSet();
    await _localSongDataSource.hardDeleteSongsNotIn(remoteIds);
  }

  /// Sync tracks with push-before-pull
  Future<void> _syncTracks(String userId) async {
    final localUnsynced = await _localTrackDataSource.getUnsyncedTracks();
    final remoteTracks = await _remoteTrackDataSource.getTracksForUser(userId);
    final remoteMap = {for (final t in remoteTracks) t.id: t};
    final pushedIds = <String>{};

    for (final local in localUnsynced) {
      final remote = remoteMap[local.id];

      if (remote == null) {
        try {
          await _remoteTrackDataSource.createTrack(local);
        } catch (_) {
          continue;
        }
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        try {
          await _remoteTrackDataSource.updateTrack(local);
        } catch (_) {
          continue;
        }
      }
      await _localTrackDataSource.markAsSynced(local.id);
      pushedIds.add(local.id);
    }

    for (final remote in remoteTracks) {
      if (!pushedIds.contains(remote.id)) {
        await _localTrackDataSource.upsertTrack(
          remote,
          markForSync: false,
        );
      }
    }

    final remoteTrackIds = remoteTracks.map((t) => t.id).toSet();
    await _localTrackDataSource.hardDeleteTracksNotIn(remoteTrackIds);
  }

  /// Sync marker sets with push-before-pull
  Future<void> _syncMarkerSets(String userId) async {
    final localUnsynced = await _localMarkerDataSource.getUnsyncedMarkerSets();
    final remoteMarkerSets =
        await _remoteMarkerDataSource.getMarkerSetsForUser(userId);
    final remoteMap = {for (final ms in remoteMarkerSets) ms.id: ms};
    final pushedIds = <String>{};

    for (final local in localUnsynced) {
      final remote = remoteMap[local.id];

      if (remote == null) {
        try {
          await _remoteMarkerDataSource.createMarkerSet(local);
        } catch (_) {
          continue;
        }
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        try {
          await _remoteMarkerDataSource.updateMarkerSet(local);
        } catch (_) {
          continue;
        }
      }
      await _localMarkerDataSource.markMarkerSetAsSynced(local.id);
      pushedIds.add(local.id);
    }

    for (final remote in remoteMarkerSets) {
      if (!pushedIds.contains(remote.id)) {
        await _localMarkerDataSource.upsertMarkerSet(
          remote,
          markForSync: false,
        );
      }
    }

    final remoteIds = remoteMarkerSets.map((ms) => ms.id).toSet();
    await _localMarkerDataSource.hardDeleteMarkerSetsNotIn(remoteIds);
  }

  /// Sync markers with push-before-pull
  Future<void> _syncMarkers(String userId) async {
    final localUnsynced = await _localMarkerDataSource.getUnsyncedMarkers();
    final remoteMarkers =
        await _remoteMarkerDataSource.getMarkersForUser(userId);
    final remoteMap = {for (final m in remoteMarkers) m.id: m};
    final pushedIds = <String>{};

    for (final local in localUnsynced) {
      final remote = remoteMap[local.id];

      if (remote == null) {
        try {
          await _remoteMarkerDataSource.createMarker(local);
        } catch (_) {
          continue;
        }
      } else {
        // Markers don't have updatedAt, compare by createdAt
        // For markers, local edits always win when unsynced
        try {
          await _remoteMarkerDataSource.updateMarker(local);
        } catch (_) {
          continue;
        }
      }
      await _localMarkerDataSource.markMarkerAsSynced(local.id);
      pushedIds.add(local.id);
    }

    for (final remote in remoteMarkers) {
      if (!pushedIds.contains(remote.id)) {
        await _localMarkerDataSource.upsertMarker(
          remote,
          markForSync: false,
        );
      }
    }

    final remoteIds = remoteMarkers.map((m) => m.id).toSet();
    await _localMarkerDataSource.hardDeleteMarkersNotIn(remoteIds);
  }

  /// Sync favorites with push-before-pull
  ///
  /// Favorites use soft-delete locally. Unsynced additions are pushed
  /// to remote. Soft-deleted favorites are pushed as remote deletions.
  /// Remote favorites not present locally are pulled in.
  Future<void> _syncFavorites(String userId) async {
    // 1. Get unsynced local favorites (both additions and deletions)
    final localUnsynced =
        await _localFavoriteTrackDataSource.getUnsyncedFavoriteRecords(userId);

    // 2. Get remote favorites (lightweight)
    final remoteFavorites =
        await _remoteFavoriteTrackDataSource.getFavoritesForSync(userId);
    final remoteTrackIds = remoteFavorites.map((f) => f.trackId).toSet();
    final pushedTrackIds = <String>{};

    // 3. Push phase
    for (final local in localUnsynced) {
      if (local.deleted) {
        // Soft-deleted locally: push deletion to remote
        try {
          await _remoteFavoriteTrackDataSource.removeFavorite(
            userId,
            local.trackId,
          );
        } catch (_) {
          continue;
        }
      } else {
        // New addition: push to remote if not already there
        if (!remoteTrackIds.contains(local.trackId)) {
          try {
            await _remoteFavoriteTrackDataSource.addFavorite(
              userId,
              local.trackId,
              local.songId,
            );
          } catch (_) {
            continue;
          }
        }
      }
      await _localFavoriteTrackDataSource
          .markAsSynced([local.trackId], userId);
      pushedTrackIds.add(local.trackId);
    }

    // 4. Clean up: hard-delete synced soft-deleted favorites
    await _localFavoriteTrackDataSource.hardDeleteSyncedDeleted(userId);

    // 5. Pull phase: add remote favorites not present locally
    //    Re-fetch remote favorites to get the latest state after pushes
    final updatedRemoteFavorites =
        await _remoteFavoriteTrackDataSource.getFavoritesForSync(userId);

    for (final remote in updatedRemoteFavorites) {
      if (!pushedTrackIds.contains(remote.trackId)) {
        await _localFavoriteTrackDataSource.upsertFavoriteRecord(
          userId: userId,
          trackId: remote.trackId,
          songId: remote.songId,
          addedAt: remote.addedAt,
          markForSync: false,
        );
      }
    }

    // 6. Cleanup: remove local synced favorites not in remote
    final updatedRemoteTrackIds =
        updatedRemoteFavorites.map((f) => f.trackId).toSet();
    await _localFavoriteTrackDataSource.hardDeleteSyncedNotIn(
      userId,
      updatedRemoteTrackIds,
    );
  }

  /// Sync playback states from remote to local (pull-only)
  Future<void> _syncPlaybackStates(String userId) async {
    final remoteStates =
        await _remotePlaybackStateDataSource.getPlaybackStatesForUser(userId);

    for (final state in remoteStates) {
      await _localPlaybackStateDataSource.savePlaybackState(state);
    }
  }

}
