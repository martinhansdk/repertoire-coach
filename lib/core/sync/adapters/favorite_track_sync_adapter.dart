import '../../../data/datasources/local/local_favorite_track_data_source.dart';
import '../../../data/datasources/remote/remote_favorite_track_data_source.dart';
import '../../../data/models/favorite_track_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for FavoriteTrackModel
class SyncableFavoriteTrack with Syncable {
  final FavoriteTrackModel model;

  SyncableFavoriteTrack(this.model);

  @override
  String get syncId => model.track.id; // trackId is the unique identifier

  @override
  DateTime get syncTimestamp => model.updatedAt;

  @override
  bool get isDeleted => model.deleted;
}

/// Sync adapter for FavoriteTrack entities
///
/// Bridges between the generic sync algorithm and favorite track-specific data sources.
/// Uses trackId as syncId (userId is implicit in the adapter context).
class FavoriteTrackSyncAdapter implements SyncAdapter<Syncable> {
  final LocalFavoriteTrackDataSource _local;
  final RemoteFavoriteTrackDataSource _remote;
  final String _userId;

  FavoriteTrackSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableFavoriteTrack>> getUnsyncedLocal() async {
    final favorites = await _local.getUnsyncedFavorites(_userId);
    return favorites.map((f) => SyncableFavoriteTrack(f)).toList();
  }

  @override
  Future<Map<String, SyncableFavoriteTrack>> getSyncedLocal() async {
    final favoriteMap = await _local.getSyncedFavorites(_userId);
    return favoriteMap.map((trackId, model) =>
        MapEntry(trackId, SyncableFavoriteTrack(model)));
  }

  @override
  Future<List<SyncableFavoriteTrack>> getAllRemote() async {
    final favorites = await _remote.getFavorites(_userId);
    return favorites.map((f) => SyncableFavoriteTrack(f)).toList();
  }

  @override
  Future<void> createOnRemote(covariant SyncableFavoriteTrack item) async {
    await _remote.addFavorite(
      _userId,
      item.model.track.id,
      item.model.track.songId,
      item.syncTimestamp,
    );
  }

  @override
  Future<void> updateOnRemote(covariant SyncableFavoriteTrack item) async {
    // Favorites are add/remove only - update means re-adding (upsert)
    await _remote.addFavorite(
      _userId,
      item.model.track.id,
      item.model.track.songId,
      item.syncTimestamp,
    );
  }

  @override
  Future<void> deleteOnRemote(String trackId, DateTime deletedAt) async {
    await _remote.removeFavorite(_userId, trackId, deletedAt);
  }

  @override
  Future<void> markSynced(String trackId, DateTime expectedUpdatedAt) async {
    await _local.markAsSynced([trackId], _userId, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableFavoriteTrack item) async {
    await _local.addFavorite(_userId, item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeleted(_userId);
  }
}
