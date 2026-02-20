import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/entities/favorite_track.dart';
import '../../domain/repositories/favorite_track_repository.dart';
import '../datasources/local/local_favorite_track_data_source.dart';
import '../datasources/local/local_track_data_source.dart';
import '../models/favorite_track_model.dart';

/// Favorite track repository implementation with offline-first sync
///
/// Uses local (Drift/SQLite) data only. Remote propagation is handled by the
/// sync service.
class FavoriteTrackRepositoryImpl implements FavoriteTrackRepository {
  final LocalFavoriteTrackDataSource _localDataSource;
  final LocalTrackDataSource _localTrackDataSource;

  FavoriteTrackRepositoryImpl(
    this._localDataSource,
    this._localTrackDataSource,
  );

  @override
  Future<List<FavoriteTrack>> getFavorites(String userId) async {
    final localFavorites = await _localDataSource.getFavorites(userId);
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
    // Fetch the track and save favorite locally; sync service handles remote.
    final trackModel = await _localTrackDataSource.getTrackById(trackId);
    if (trackModel == null) {
      debugPrint('Cannot add favorite: track $trackId not found locally');
      return;
    }

    final favorite = FavoriteTrackModel(
      addedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      track: trackModel.toEntity(),
    );

    await _localDataSource.addFavorite(userId, favorite, markForSync: true);
  }

  @override
  Future<void> removeFavorite(String userId, String trackId) async {
    // Delete locally; sync service handles remote.
    await _localDataSource.removeFavorite(userId, trackId);
  }

  @override
  Future<int> getFavoriteCount(String userId) async {
    return await _localDataSource.getFavoriteCount(userId);
  }
}
