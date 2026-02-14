import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

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
    // On web, skip local database entirely and fetch from remote
    // This avoids JOIN failures when tracks/songs/concerts tables don't exist in IndexedDB
    if (kIsWeb) {
      debugPrint('[FavoriteTrackRepository] Web platform detected, fetching from remote');
      debugPrint('[FavoriteTrackRepository] Auth status: ${_supabaseService.isAuthenticated}');
      debugPrint('[FavoriteTrackRepository] Remote data source available: ${_remoteDataSource != null}');

      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          final remoteFavorites = await _remoteDataSource.getFavorites(userId);
          debugPrint('[FavoriteTrackRepository] Received ${remoteFavorites.length} favorites from remote');

          final entities = remoteFavorites.map((model) {
            final entity = model.toEntity();
            debugPrint('[FavoriteTrackRepository] Entity: trackName=${entity.trackName}, audioUrl=${entity.audioUrl}');
            return entity;
          }).toList();

          debugPrint('[FavoriteTrackRepository] Returning ${entities.length} entities');
          return entities;
        } catch (e) {
          debugPrint('[FavoriteTrackRepository] ERROR fetching favorites from remote on web: $e');
          return [];
        }
      }
      debugPrint('[FavoriteTrackRepository] Not authenticated or no remote data source, returning empty list');
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
    // On web, check remote directly
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          final favorites = await _remoteDataSource.getFavorites(userId);
          return favorites.any((f) => f.trackId == trackId);
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
        try {
          await _remoteDataSource.addFavorite(userId, trackId, songId);
        } catch (e) {
          debugPrint('Failed to add favorite to remote on web: $e');
          rethrow;
        }
      }
      return;
    }

    // Mobile/Desktop: Save to local database and sync to remote
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
    // On web, delete from remote only (skip local database)
    if (kIsWeb) {
      if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
        try {
          await _remoteDataSource.removeFavorite(userId, trackId);
        } catch (e) {
          debugPrint('Failed to remove favorite from remote on web: $e');
          rethrow;
        }
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
