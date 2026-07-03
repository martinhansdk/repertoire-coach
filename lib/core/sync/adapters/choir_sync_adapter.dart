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

  @override
  bool get isDeleted => model.deleted;
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
  Future<void> createOnRemote(covariant SyncableChoir item) async {
    await _remote.createChoir(item.model, _userId);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableChoir item) async {
    await _remote.updateChoir(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id, DateTime deletedAt) async {
    await _remote.deleteChoir(id, deletedAt);
  }

  @override
  Future<void> markSynced(String id, DateTime expectedUpdatedAt) async {
    await _local.markChoirAsSynced(id, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableChoir item) async {
    await _local.upsertChoir(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedChoirs();
  }
}
