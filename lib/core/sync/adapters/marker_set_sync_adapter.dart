import '../../../data/datasources/local/local_marker_data_source.dart';
import '../../../data/datasources/remote/remote_marker_data_source.dart';
import '../../../data/models/marker_set_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for MarkerSetModel
class SyncableMarkerSet with Syncable {
  final MarkerSetModel model;

  SyncableMarkerSet(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;
}

/// Sync adapter for MarkerSet entities
///
/// Bridges between the generic sync algorithm and marker set-specific data sources.
class MarkerSetSyncAdapter implements SyncAdapter<SyncableMarkerSet> {
  final LocalMarkerDataSource _local;
  final RemoteMarkerDataSource _remote;
  final String _userId;

  MarkerSetSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableMarkerSet>> getUnsyncedLocal() async {
    final markerSets = await _local.getUnsyncedMarkerSets();
    return markerSets.map((ms) => SyncableMarkerSet(ms)).toList();
  }

  @override
  Future<Map<String, SyncableMarkerSet>> getSyncedLocal() async {
    final markerSetMap = await _local.getSyncedMarkerSets();
    return markerSetMap.map((id, model) => MapEntry(id, SyncableMarkerSet(model)));
  }

  @override
  Future<List<SyncableMarkerSet>> getAllRemote() async {
    final markerSets = await _remote.getMarkerSets(_userId);
    return markerSets.map((ms) => SyncableMarkerSet(ms)).toList();
  }

  @override
  bool isLocallyDeleted(SyncableMarkerSet item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(SyncableMarkerSet item) async {
    await _remote.createMarkerSet(item.model);
  }

  @override
  Future<void> updateOnRemote(SyncableMarkerSet item) async {
    await _remote.updateMarkerSet(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    await _remote.deleteMarkerSet(id);
  }

  @override
  Future<void> markSynced(String id) async {
    await _local.markMarkerSetAsSynced(id);
  }

  @override
  Future<void> upsertLocal(SyncableMarkerSet item) async {
    await _local.upsertMarkerSet(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    await _local.hardDeleteMarkerSetsNotIn(keepIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedMarkerSets();
  }
}
