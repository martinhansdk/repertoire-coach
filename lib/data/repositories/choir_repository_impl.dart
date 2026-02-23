import '../../core/services/error_reporter.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/supabase_service.dart';
import '../../domain/entities/choir.dart';
import '../../domain/repositories/choir_repository.dart';
import '../datasources/local/local_choir_data_source.dart';
import '../datasources/remote/remote_choir_data_source.dart';
import '../models/choir_model.dart';

/// Choir repository implementation with offline-first sync
///
/// Uses both local (Drift/SQLite) and remote (Supabase) data sources.
/// - Reads always from local DB (fast, works offline)
/// - Writes to both local AND remote when authenticated
/// - Background sync ensures data consistency
class ChoirRepositoryImpl implements ChoirRepository {
  final LocalChoirDataSource _localDataSource;
  final RemoteChoirDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;
  final Uuid _uuid = const Uuid();

  ChoirRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
  );

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
      updatedAt: DateTime.now().toUtc(),
    );

    // Save to local database (this also adds the owner as a member)
    await _localDataSource.createChoir(choirModel, ownerId);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.createChoir(choirModel, ownerId);
        // Mark as synced in local DB
        await _localDataSource.markChoirAsSynced(id);
        await _localDataSource.markMemberAsSynced(id, ownerId);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'choir_repository');
      }
    }

    return id;
  }

  @override
  Future<void> updateChoir(Choir choir) async {
    final choirModel = ChoirModel.fromEntity(choir);

    // Update in local database
    await _localDataSource.updateChoir(choirModel);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.updateChoir(choirModel);
        // Mark as synced in local DB
        await _localDataSource.markChoirAsSynced(choir.id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'choir_repository');
      }
    }
  }

  @override
  Future<void> deleteChoir(String id) async {
    // Delete from local database (soft delete)
    await _localDataSource.deleteChoir(id);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.deleteChoir(id);
        // Mark as synced in local DB
        await _localDataSource.markChoirAsSynced(id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'choir_repository');
      }
    }
  }

  // ============================================================================
  // CHOIR MEMBERSHIP OPERATIONS
  // ============================================================================

  @override
  Future<void> addMember(String choirId, String userId) async {
    // Add to local database
    await _localDataSource.addMember(choirId, userId);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.addMember(choirId, userId);
        // Mark as synced in local DB
        await _localDataSource.markMemberAsSynced(choirId, userId);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'choir_repository');
      }
    }
  }

  @override
  Future<bool> removeMember(String choirId, String userId) async {
    // Don't allow removing the owner
    final isOwner = await _localDataSource.isOwner(choirId, userId);
    if (isOwner) {
      throw Exception('Cannot remove choir owner. Delete the choir instead.');
    }

    // Remove from local database
    final removed = await _localDataSource.removeMember(choirId, userId);

    // Sync to remote if authenticated and member was actually removed
    if (removed &&
        _supabaseService.isAuthenticated &&
        _remoteDataSource != null) {
      try {
        await _remoteDataSource.removeMember(choirId, userId);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'choir_repository');
      }
    }

    return removed;
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
