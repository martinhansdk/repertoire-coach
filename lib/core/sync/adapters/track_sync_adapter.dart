import '../../../data/datasources/local/local_track_data_source.dart';
import '../../../data/datasources/remote/remote_track_data_source.dart';
import '../../../data/models/track_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for TrackModel
class SyncableTrack with Syncable {
  final TrackModel model;

  SyncableTrack(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;
}

/// Sync adapter for Track entities
///
/// Bridges between the generic sync algorithm and track-specific data sources.
class TrackSyncAdapter implements SyncAdapter<SyncableTrack> {
  final LocalTrackDataSource _local;
  final RemoteTrackDataSource _remote;
  final String _userId;

  TrackSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableTrack>> getUnsyncedLocal() async {
    final tracks = await _local.getUnsyncedTracks();
    return tracks.map((t) => SyncableTrack(t)).toList();
  }

  @override
  Future<Map<String, SyncableTrack>> getSyncedLocal() async {
    final trackMap = await _local.getSyncedTracks();
    return trackMap.map((id, model) => MapEntry(id, SyncableTrack(model)));
  }

  @override
  Future<List<SyncableTrack>> getAllRemote() async {
    final tracks = await _remote.getTracks(_userId);
    return tracks.map((t) => SyncableTrack(t)).toList();
  }

  @override
  bool isLocallyDeleted(SyncableTrack item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(SyncableTrack item) async {
    await _remote.createTrack(item.model);
  }

  @override
  Future<void> updateOnRemote(SyncableTrack item) async {
    await _remote.updateTrack(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    await _remote.deleteTrack(id);
  }

  @override
  Future<void> markSynced(String id) async {
    await _local.markAsSynced(id);
  }

  @override
  Future<void> upsertLocal(SyncableTrack item) async {
    await _local.upsertTrack(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    await _local.hardDeleteTracksNotIn(keepIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeleted();
  }
}
