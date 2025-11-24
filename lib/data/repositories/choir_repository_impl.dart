import 'package:uuid/uuid.dart';

import '../../domain/entities/choir.dart';
import '../../domain/repositories/choir_repository.dart';
import '../datasources/local/local_choir_data_source.dart';
import '../models/choir_model.dart';

/// Choir repository implementation using local Drift database
///
/// Provides offline-first data persistence with SQLite.
/// All data is stored locally and works without internet connection.
/// Future versions will add cloud sync with Supabase.
class ChoirRepositoryImpl implements ChoirRepository {
  final LocalChoirDataSource _localDataSource;
  final Uuid _uuid = const Uuid();

  ChoirRepositoryImpl(this._localDataSource);

  // ============================================================================
  // CHOIR OPERATIONS
  // ============================================================================

  @override
  Future<List<Choir>> getChoirs(String userId) async {
    // Get all choirs from local database where user is a member
    final choirModels = await _localDataSource.getChoirs(userId);

    // Convert to domain entities
    return choirModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Choir?> getChoirById(String id) async {
    final choirModel = await _localDataSource.getChoirById(id);

    return choirModel?.toEntity();
  }

  @override
  Future<String> createChoir(String name, String ownerId) async {
    // Generate unique ID
    final id = _uuid.v4();

    // Create choir model
    final choirModel = ChoirModel(
      id: id,
      name: name,
      ownerId: ownerId,
      createdAt: DateTime.now().toUtc(),
    );

    // Save to database (this also adds the owner as a member)
    await _localDataSource.createChoir(choirModel, ownerId);

    return id;
  }

  @override
  Future<void> updateChoir(Choir choir) async {
    final choirModel = ChoirModel.fromEntity(choir);
    await _localDataSource.updateChoir(choirModel);
  }

  @override
  Future<void> deleteChoir(String id) async {
    await _localDataSource.deleteChoir(id);
  }

  // ============================================================================
  // CHOIR MEMBERSHIP OPERATIONS
  // ============================================================================

  @override
  Future<void> addMember(String choirId, String userId) async {
    await _localDataSource.addMember(choirId, userId);
  }

  @override
  Future<bool> removeMember(String choirId, String userId) async {
    // Don't allow removing the owner
    final isOwner = await _localDataSource.isOwner(choirId, userId);
    if (isOwner) {
      throw Exception('Cannot remove choir owner. Delete the choir instead.');
    }

    return await _localDataSource.removeMember(choirId, userId);
  }

  @override
  Future<List<String>> getMembers(String choirId) async {
    return await _localDataSource.getChoirMembers(choirId);
  }

  @override
  Future<bool> isMember(String choirId, String userId) async {
    return await _localDataSource.isMember(choirId, userId);
  }

  @override
  Future<bool> isOwner(String choirId, String userId) async {
    return await _localDataSource.isOwner(choirId, userId);
  }

  @override
  Future<int> getMemberCount(String choirId) async {
    return await _localDataSource.getMemberCount(choirId);
  }
}
