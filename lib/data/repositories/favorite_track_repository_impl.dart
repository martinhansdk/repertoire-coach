import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../../core/services/supabase_service.dart';
import '../../domain/entities/favorite_track.dart';
import '../../domain/repositories/favorite_track_repository.dart';
import '../datasources/local/local_favorite_track_data_source.dart';
import '../datasources/remote/remote_favorite_track_data_source.dart';

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
    // On web, skip local database entirely and fetch from remote
    // This avoids JOIN failures when tracks/songs/concerts tables don't exist in IndexedDB
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          final remoteFavorites = await _remoteDataSource.getFavorites(userId);
          return remoteFavorites.map((model) => model.toEntity()).toList();
        } catch (e) {
          debugPrint('Failed to fetch favorites from remote on web: $e');
          return [];
        }
      }
      return [];
    }

    // Mobile/Desktop: Try to get from local database first
    final localFavorites = await _localDataSource.getFavorites(userId);

    // If local database is empty and user is authenticated, fetch from remote
    if (localFavorites.isEmpty &&
        _supabaseService.isAuthenticated &&
        _remoteDataSource != null) {
      try {
        final remoteFavorites = await _remoteDataSource.getFavorites(userId);

        // Sync remote favorites to local database
        for (final favorite in remoteFavorites) {
          await _localDataSource.addFavorite(userId, favorite, markForSync: false);
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
    // On web, check remote directly
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          final favorites = await _remoteDataSource.getFavorites(userId);
          return favorites.any((f) => f.track.id == trackId);
        } catch (e) {
          debugPrint('Failed to check favorite status from remote on web: $e');
          return false;
        }
      }
      return false;
    }

    // Mobile/Desktop: Check local database
    return await _localDataSource.isFavorite(userId, trackId);
  }

  @override
  Future<void> addFavorite(
    String userId,
    String trackId,
    String songId,
  ) async {
    // On web, write to remote only (skip local database)
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        await _remoteDataSource.addFavorite(userId, trackId, songId);
      }
      return;
    }

    // Mobile/Desktop: Save to local database and sync to remote
    // Note: The local data source will query and populate the full Track object
    // This placeholder approach needs refactoring for consistency
    // TODO: Refactor to fetch Track first, then create FavoriteTrackModel
    throw UnimplementedError(
      'addFavorite for mobile/desktop needs refactoring to work with Track objects',
    );
  }

  @override
  Future<void> removeFavorite(String userId, String trackId) async {
    // On web, delete from remote only (skip local database)
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        await _remoteDataSource.removeFavorite(userId, trackId);
      }
      return;
    }

    // Mobile/Desktop: Delete from local database and sync to remote
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
    // On web, count from remote directly
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          final favorites = await _remoteDataSource.getFavorites(userId);
          return favorites.length;
        } catch (e) {
          debugPrint('Failed to get favorite count from remote on web: $e');
          return 0;
        }
      }
      return 0;
    }

    // Mobile/Desktop: Count from local database
    return await _localDataSource.getFavoriteCount(userId);
  }
}
