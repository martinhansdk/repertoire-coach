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
}

/// Sync adapter for Song entities
///
/// Bridges between the generic sync algorithm and song-specific data sources.
class SongSyncAdapter implements SyncAdapter<SyncableSong> {
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
    final songs = await _remote.getSongs(_userId);
    return songs.map((s) => SyncableSong(s)).toList();
  }

  @override
  bool isLocallyDeleted(SyncableSong item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(SyncableSong item) async {
    await _remote.createSong(item.model);
  }

  @override
  Future<void> updateOnRemote(SyncableSong item) async {
    await _remote.updateSong(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    await _remote.deleteSong(id);
  }

  @override
  Future<void> markSynced(String id) async {
    await _local.markAsSynced(id);
  }

  @override
  Future<void> upsertLocal(SyncableSong item) async {
    await _local.upsertSong(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    await _local.hardDeleteSongsNotIn(keepIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeleted();
  }
}
