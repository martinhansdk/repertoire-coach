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

  @override
  bool get isDeleted => model.deleted;
}

/// Sync adapter for MarkerSet entities
///
/// Bridges between the generic sync algorithm and marker set-specific data sources.
class MarkerSetSyncAdapter implements SyncAdapter<Syncable> {
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
    final markerSets = await _remote.getMarkerSetsForUser(_userId);
    return markerSets.map((ms) => SyncableMarkerSet(ms)).toList();
  }

  @override
  Future<void> createOnRemote(covariant SyncableMarkerSet item) async {
    await _remote.createMarkerSet(item.model);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableMarkerSet item) async {
    await _remote.updateMarkerSet(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id, DateTime deletedAt) async {
    await _remote.deleteMarkerSet(id, deletedAt);
  }

  @override
  Future<void> markSynced(String id, DateTime expectedUpdatedAt) async {
    await _local.markMarkerSetAsSynced(id, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableMarkerSet item) async {
    await _local.upsertMarkerSet(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedMarkerSets();
  }
}
