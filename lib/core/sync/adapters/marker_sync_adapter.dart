import '../../../data/datasources/local/local_marker_data_source.dart';
import '../../../data/datasources/remote/remote_marker_data_source.dart';
import '../../../data/models/marker_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for MarkerModel
class SyncableMarker with Syncable {
  final MarkerModel model;

  SyncableMarker(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;
}

/// Sync adapter for Marker entities
///
/// Bridges between the generic sync algorithm and marker-specific data sources.
class MarkerSyncAdapter implements SyncAdapter<SyncableMarker> {
  final LocalMarkerDataSource _local;
  final RemoteMarkerDataSource _remote;
  final String _userId;

  MarkerSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableMarker>> getUnsyncedLocal() async {
    final markers = await _local.getUnsyncedMarkers();
    return markers.map((m) => SyncableMarker(m)).toList();
  }

  @override
  Future<Map<String, SyncableMarker>> getSyncedLocal() async {
    final markerMap = await _local.getSyncedMarkers();
    return markerMap.map((id, model) => MapEntry(id, SyncableMarker(model)));
  }

  @override
  Future<List<SyncableMarker>> getAllRemote() async {
    final markers = await _remote.getMarkers(_userId);
    return markers.map((m) => SyncableMarker(m)).toList();
  }

  @override
  bool isLocallyDeleted(SyncableMarker item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(SyncableMarker item) async {
    await _remote.createMarker(item.model);
  }

  @override
  Future<void> updateOnRemote(SyncableMarker item) async {
    await _remote.updateMarker(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    await _remote.deleteMarker(id);
  }

  @override
  Future<void> markSynced(String id) async {
    await _local.markMarkerAsSynced(id);
  }

  @override
  Future<void> upsertLocal(SyncableMarker item) async {
    await _local.upsertMarker(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    await _local.hardDeleteMarkersNotIn(keepIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedMarkers();
  }
}
