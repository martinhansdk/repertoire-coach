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
}

/// Sync adapter for ChoirMember entities
///
/// Bridges between the generic sync algorithm and choir member-specific data sources.
/// Uses composite keys (choirId:userId) for sync identification.
class ChoirMemberSyncAdapter implements SyncAdapter<SyncableChoirMember> {
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
    final members = await _remote.getChoirMembers(_userId);
    return members.map((m) => SyncableChoirMember(m)).toList();
  }

  @override
  bool isLocallyDeleted(SyncableChoirMember item) {
    return item.model.deleted;
  }

  @override
  Future<void> createOnRemote(SyncableChoirMember item) async {
    await _remote.addMember(item.model.choirId, item.model.userId);
  }

  @override
  Future<void> updateOnRemote(SyncableChoirMember item) async {
    // Choir members don't really have "update" - they're just membership records
    // If we need to update, we can treat it as re-adding (upsert on remote)
    await _remote.addMember(item.model.choirId, item.model.userId);
  }

  @override
  Future<void> deleteOnRemote(String compositeId) async {
    // Parse composite ID "choirId:userId"
    final parts = compositeId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid composite ID format: $compositeId');
    }
    final choirId = parts[0];
    final userId = parts[1];
    await _remote.removeMember(choirId, userId);
  }

  @override
  Future<void> markSynced(String compositeId) async {
    // Parse composite ID "choirId:userId"
    final parts = compositeId.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid composite ID format: $compositeId');
    }
    final choirId = parts[0];
    final userId = parts[1];
    await _local.markMemberAsSynced(choirId, userId);
  }

  @override
  Future<void> upsertLocal(SyncableChoirMember item) async {
    await _local.upsertMember(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedNotIn(Set<String> keepCompositeIds) async {
    await _local.hardDeleteSyncedMembersNotIn(keepCompositeIds);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeletedMembers();
  }
}
