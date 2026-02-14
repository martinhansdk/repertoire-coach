import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/datasources/local/local_favorite_track_data_source.dart';
import '../../data/datasources/remote/remote_favorite_track_data_source.dart';
import '../../data/repositories/favorite_track_repository_impl.dart';
import '../../domain/entities/favorite_track.dart';
import '../../domain/repositories/favorite_track_repository.dart';
import 'auth_provider.dart';

/// Provides the database instance
final databaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

/// Provides the local favorite track data source
final localFavoriteTrackDataSourceProvider =
    Provider<LocalFavoriteTrackDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalFavoriteTrackDataSource(database);
});

/// Provides the remote favorite track data source (nullable if not authenticated)
final remoteFavoriteTrackDataSourceProvider =
    Provider<RemoteFavoriteTrackDataSource?>((ref) {
  if (!SupabaseService.isInitialized) {
    return null;
  }

  final supabase = SupabaseService.instance.client;
  return RemoteFavoriteTrackDataSource(supabase);
});

/// Provides the favorite track repository
final favoriteTrackRepositoryProvider =
    Provider<FavoriteTrackRepository>((ref) {
  final localDataSource = ref.watch(localFavoriteTrackDataSourceProvider);
  final remoteDataSource = ref.watch(remoteFavoriteTrackDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);

  return FavoriteTrackRepositoryImpl(
    localDataSource,
    remoteDataSource,
    supabaseService,
  );
});

/// Provides all favorite tracks for the current user
///
/// Returns empty list if user is not authenticated.
/// Favorites are sorted by added_at descending (most recent first).
final favoritesProvider = FutureProvider<List<FavoriteTrack>>((ref) async {
  final userId = ref.watch(supabaseServiceProvider).currentUserId;
  if (userId == null) return [];

  final repository = ref.watch(favoriteTrackRepositoryProvider);
  return await repository.getFavorites(userId);
});

/// Checks if a specific track is favorited by the current user
///
/// Returns false if user is not authenticated.
final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, trackId) async {
  final userId = ref.watch(supabaseServiceProvider).currentUserId;
  if (userId == null) return false;

  final repository = ref.watch(favoriteTrackRepositoryProvider);
  return await repository.isFavorite(userId, trackId);
});

/// Provides the count of favorite tracks for the current user
///
/// Used for startup logic to determine which tab to show.
/// Returns 0 if user is not authenticated.
final favoriteCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(supabaseServiceProvider).currentUserId;
  if (userId == null) return 0;

  final repository = ref.watch(favoriteTrackRepositoryProvider);
  return await repository.getFavoriteCount(userId);
});

/// Provides actions for managing favorites
final favoriteTrackActionsProvider = Provider((ref) {
  return FavoriteTrackActions(ref);
});

/// Actions for managing favorite tracks
class FavoriteTrackActions {
  final Ref _ref;

  FavoriteTrackActions(this._ref);

  /// Toggle favorite status for a track
  ///
  /// If favorited, removes it. If not favorited, adds it.
  Future<void> toggleFavorite(String trackId, String songId) async {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    final repository = _ref.read(favoriteTrackRepositoryProvider);
    final isFavorite = await repository.isFavorite(userId, trackId);

    if (isFavorite) {
      await removeFavorite(trackId);
    } else {
      await addFavorite(trackId, songId);
    }
  }

  /// Add a track to favorites
  Future<void> addFavorite(String trackId, String songId) async {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    final repository = _ref.read(favoriteTrackRepositoryProvider);
    await repository.addFavorite(userId, trackId, songId);

    // Invalidate providers to trigger UI refresh
    _ref.invalidate(favoritesProvider);
    _ref.invalidate(isFavoriteProvider(trackId));
    _ref.invalidate(favoriteCountProvider);
  }

  /// Remove a track from favorites
  Future<void> removeFavorite(String trackId) async {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    final repository = _ref.read(favoriteTrackRepositoryProvider);
    await repository.removeFavorite(userId, trackId);

    // Invalidate providers to trigger UI refresh
    _ref.invalidate(favoritesProvider);
    _ref.invalidate(isFavoriteProvider(trackId));
    _ref.invalidate(favoriteCountProvider);
  }
}
