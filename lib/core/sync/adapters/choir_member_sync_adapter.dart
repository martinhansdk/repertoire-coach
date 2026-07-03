import '../../../data/datasources/local/local_choir_data_source.dart';
import '../../../data/datasources/remote/remote_choir_data_source.dart';
import '../../../data/models/choir_member_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for ChoirMemberModel
class SyncableChoirMember with Syncable {
  final ChoirMemberModel model;

  SyncableChoirMember(this.model);

  @override
  String get syncId => '${model.choirId}:${model.userId}';

  @override
  DateTime get syncTimestamp => model.updatedAt;

  @override
  bool get isDeleted => model.deleted;
}

/// Sync adapter for ChoirMember entities
///
/// Bridges between the generic sync algorithm and choir member-specific data sources.
/// Uses composite keys (choirId:userId) for sync identification.
class ChoirMemberSyncAdapter implements SyncAdapter<Syncable> {
  final LocalChoirDataSource _local;
  final RemoteChoirDataSource _remote;
  final String _userId;

  ChoirMemberSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableChoirMember>> getUnsyncedLocal() async {
    final members = await _local.getUnsyncedMembers();
    return members.map((m) => SyncableChoirMember(m)).toList();
  }

  @override
  Future<Map<String, SyncableChoirMember>> getSyncedLocal() async {
    final memberMap = await _local.getSyncedMembers();
    return memberMap.map((compositeId, model) =>
        MapEntry(compositeId, SyncableChoirMember(model)));
  }

  @override
  Future<List<SyncableChoirMember>> getAllRemote() async {
    final members = await _remote.getChoirMembersForUser(_userId);
    return members.map((m) => SyncableChoirMember(m)).toList();
  }

  @override
  Future<void> createOnRemote(covariant SyncableChoirMember item) async {
    await _remote.addMember(
        item.model.choirId, item.model.userId, item.syncTimestamp);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableChoirMember item) async {
    // Choir members don't really have "update" - they're just membership records
    // If we need to update, we can treat it as re-adding (upsert on remote)
    await _remote.addMember(
        item.model.choirId, item.model.userId, item.syncTimestamp);
  }

  @override
  Future<void> deleteOnRemote(String compositeId, DateTime deletedAt) async {
    // Parse composite ID "choirId:userId"
    final parts = compositeId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid composite ID format: $compositeId');
    }
    final choirId = parts[0];
    final userId = parts[1];
    await _remote.removeMember(choirId, userId, deletedAt);
  }

  @override
  Future<void> markSynced(String compositeId, DateTime expectedUpdatedAt) async {
    // Parse composite ID "choirId:userId"
    final parts = compositeId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid composite ID format: $compositeId');
    }
    final choirId = parts[0];
    final userId = parts[1];
    await _local.markMemberAsSynced(choirId, userId, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableChoirMember item) async {
    await _local.upsertMember(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedMembers();
  }
}
