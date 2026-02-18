import '../../../data/datasources/local/local_choir_data_source.dart';
import '../../../data/datasources/remote/remote_choir_data_source.dart';
import '../../../data/models/choir_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for ChoirModel
class SyncableChoir with Syncable {
  final ChoirModel model;

  SyncableChoir(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;
}

/// Sync adapter for Choir entities
///
/// Bridges between the generic sync algorithm and choir-specific data sources.
class ChoirSyncAdapter implements SyncAdapter<Syncable> {
  final LocalChoirDataSource _local;
  final RemoteChoirDataSource _remote;
  final String _userId;

  ChoirSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableChoir>> getUnsyncedLocal() async {
    final choirs = await _local.getUnsyncedChoirs();
    return choirs.map((c) => SyncableChoir(c)).toList();
  }

  @override
  Future<Map<String, SyncableChoir>> getSyncedLocal() async {
    final choirMap = await _local.getSyncedChoirs();
    return choirMap.map((id, model) => MapEntry(id, SyncableChoir(model)));
  }

  @override
  Future<List<SyncableChoir>> getAllRemote() async {
    final choirs = await _remote.getChoirs(_userId);
    return choirs.map((c) => SyncableChoir(c)).toList();
  }

  @override
  bool isLocallyDeleted(covariant SyncableChoir item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(covariant SyncableChoir item) async {
    await _remote.createChoir(item.model, _userId);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableChoir item) async {
    await _remote.updateChoir(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id) async {
    await _remote.deleteChoir(id);
  }

  @override
  Future<void> markSynced(String id) async {
    await _local.markChoirAsSynced(id);
  }

  @override
  Future<void> upsertLocal(covariant SyncableChoir item) async {
    await _local.upsertChoir(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepIds) async {
    await _local.hardDeleteSyncedChoirsNotIn(keepIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedChoirs();
  }
}
