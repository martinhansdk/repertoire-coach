import '../../../data/datasources/local/local_song_data_source.dart';
import '../../../data/datasources/remote/remote_song_data_source.dart';
import '../../../data/models/song_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for SongModel
class SyncableSong with Syncable {
  final SongModel model;

  SyncableSong(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;

  @override
  bool get isDeleted => model.deleted;
}

/// Sync adapter for Song entities
///
/// Bridges between the generic sync algorithm and song-specific data sources.
class SongSyncAdapter implements SyncAdapter<Syncable> {
  final LocalSongDataSource _local;
  final RemoteSongDataSource _remote;
  final String _userId;

  SongSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableSong>> getUnsyncedLocal() async {
    final songs = await _local.getUnsyncedSongs();
    return songs.map((s) => SyncableSong(s)).toList();
  }

  @override
  Future<Map<String, SyncableSong>> getSyncedLocal() async {
    final songMap = await _local.getSyncedSongs();
    return songMap.map((id, model) => MapEntry(id, SyncableSong(model)));
  }

  @override
  Future<List<SyncableSong>> getAllRemote() async {
    final songs = await _remote.getSongsForUser(_userId);
    return songs.map((s) => SyncableSong(s)).toList();
  }

  @override
  Future<void> createOnRemote(covariant SyncableSong item) async {
    await _remote.createSong(item.model);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableSong item) async {
    await _remote.updateSong(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id, DateTime deletedAt) async {
    await _remote.deleteSong(id, deletedAt);
  }

  @override
  Future<void> markSynced(String id, DateTime expectedUpdatedAt) async {
    await _local.markAsSynced(id, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableSong item) async {
    await _local.upsertSong(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeleted();
  }
}
