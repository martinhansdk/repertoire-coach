import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../domain/entities/favorite_track.dart';
import '../../domain/repositories/favorite_track_repository.dart';
import '../datasources/local/local_favorite_track_data_source.dart';
import '../datasources/remote/remote_favorite_track_data_source.dart';
import '../models/favorite_track_model.dart';

/// Favorite track repository implementation with offline-first sync
///
/// Uses both local (Drift/SQLite) and remote (Supabase) data sources.
/// - Reads always from local DB (fast, works offline)
/// - Writes to both local AND remote when authenticated
/// - Background sync ensures data consistency
class FavoriteTrackRepositoryImpl implements FavoriteTrackRepository {
  final LocalFavoriteTrackDataSource _localDataSource;
  final RemoteFavoriteTrackDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;

  FavoriteTrackRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
  );

  @override
  Future<List<FavoriteTrack>> getFavorites(String userId) async {
    // Try to get from local database first
    final localFavorites = await _localDataSource.getFavorites(userId);

    // If local database is empty and user is authenticated, fetch from remote
    if (localFavorites.isEmpty &&
        _supabaseService.isAuthenticated &&
        _remoteDataSource != null) {
      try {
        final remoteFavorites = await _remoteDataSource.getFavorites(userId);

        // Sync remote favorites to local database
        for (final favorite in remoteFavorites) {
          await _localDataSource.addFavorite(favorite, markForSync: false);
        }

        // Return the remote favorites
        return remoteFavorites.map((model) => model.toEntity()).toList();
      } catch (e) {
        debugPrint('Failed to fetch favorites from remote: $e');
        // Fall through to return empty local list
      }
    }

    // Convert local favorites to domain entities
    return localFavorites.map((model) => model.toEntity()).toList();
  }

  @override
  Future<bool> isFavorite(String userId, String trackId) async {
    return await _localDataSource.isFavorite(userId, trackId);
  }

  @override
  Future<void> addFavorite(
    String userId,
    String trackId,
    String songId,
  ) async {
    final favorite = FavoriteTrackModel(
      userId: userId,
      trackId: trackId,
      songId: songId,
      addedAt: DateTime.now(),
      // Denormalized fields will be populated by local data source query
      trackName: '',
      songTitle: '',
      choirName: '',
    );

    // Save to local database (marks for sync)
    await _localDataSource.addFavorite(favorite, markForSync: true);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.addFavorite(userId, trackId, songId);
        await _localDataSource.markAsSynced([trackId], userId);
      } catch (e) {
        // Log error but don't fail the operation - will sync later
        debugPrint('Failed to sync favorite to remote: $e');
      }
    }
  }

  @override
  Future<void> removeFavorite(String userId, String trackId) async {
    // Delete from local database
    await _localDataSource.removeFavorite(userId, trackId);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.removeFavorite(userId, trackId);
      } catch (e) {
        // Log error but don't fail the operation - will sync later
        debugPrint('Failed to sync favorite removal to remote: $e');
      }
    }
  }

  @override
  Future<int> getFavoriteCount(String userId) async {
    return await _localDataSource.getFavoriteCount(userId);
  }
}
