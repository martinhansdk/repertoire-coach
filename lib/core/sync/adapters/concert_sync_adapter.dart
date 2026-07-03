import '../../../data/datasources/local/local_concert_data_source.dart';
import '../../../data/datasources/remote/remote_concert_data_source.dart';
import '../../../data/models/concert_model.dart';
import '../sync_adapter.dart';
import '../syncable.dart';

/// Syncable wrapper for ConcertModel
class SyncableConcert with Syncable {
  final ConcertModel model;

  SyncableConcert(this.model);

  @override
  String get syncId => model.id;

  @override
  DateTime get syncTimestamp => model.updatedAt;

  @override
  bool get isDeleted => model.deleted;
}

/// Sync adapter for Concert entities
///
/// Bridges between the generic sync algorithm and concert-specific data sources.
class ConcertSyncAdapter implements SyncAdapter<Syncable> {
  final LocalConcertDataSource _local;
  final RemoteConcertDataSource _remote;
  final String _userId;

  ConcertSyncAdapter(this._local, this._remote, this._userId);

  @override
  Future<List<SyncableConcert>> getUnsyncedLocal() async {
    final concerts = await _local.getUnsyncedConcerts();
    return concerts.map((c) => SyncableConcert(c)).toList();
  }

  @override
  Future<Map<String, SyncableConcert>> getSyncedLocal() async {
    final concertMap = await _local.getSyncedConcerts();
    return concertMap.map((id, model) => MapEntry(id, SyncableConcert(model)));
  }

  @override
  Future<List<SyncableConcert>> getAllRemote() async {
    final concerts = await _remote.getConcerts(_userId);
    return concerts.map((c) => SyncableConcert(c)).toList();
  }

  @override
  Future<void> createOnRemote(covariant SyncableConcert item) async {
    await _remote.createConcert(item.model);
  }

  @override
  Future<void> updateOnRemote(covariant SyncableConcert item) async {
    await _remote.updateConcert(item.model);
  }

  @override
  Future<void> deleteOnRemote(String id, DateTime deletedAt) async {
    await _remote.deleteConcert(id, deletedAt);
  }

  @override
  Future<void> markSynced(String id, DateTime expectedUpdatedAt) async {
    await _local.markAsSynced(id, expectedUpdatedAt);
  }

  @override
  Future<void> upsertLocal(covariant SyncableConcert item) async {
    await _local.upsertConcert(item.model, markForSync: false);
  }

  @override
  Future<void> hardDeleteSyncedDeleted() async {
    await _local.hardDeleteSyncedDeleted();
  }
}
