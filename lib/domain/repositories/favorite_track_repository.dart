import '../entities/favorite_track.dart';

/// Repository interface for favorite track operations
///
/// Manages user's favorite tracks with full denormalized data for display.
/// Implementations should handle both local (Drift) and remote (Supabase) storage
/// following the offline-first pattern used throughout the app.
abstract class FavoriteTrackRepository {
  /// Get all favorite tracks for a user with denormalized display data
  ///
  /// Returns favorites sorted by [addedAt] descending (most recent first).
  /// Includes denormalized data: track name, song title, choir name, audio URL, duration.
  Future<List<FavoriteTrack>> getFavorites(String userId);

  /// Check if a specific track is favorited by the user
  ///
  /// Returns true if the track is in the user's favorites, false otherwise.
  Future<bool> isFavorite(String userId, String trackId);

  /// Add a track to user's favorites
  ///
  /// Creates a favorite relationship between the user and track.
  /// If already favorited, this operation is idempotent (no error).
  ///
  /// [userId] - ID of the user adding the favorite
  /// [trackId] - ID of the track to favorite
  /// [songId] - ID of the song containing the track (for efficient queries)
  Future<void> addFavorite(String userId, String trackId, String songId);

  /// Remove a track from user's favorites
  ///
  /// Deletes the favorite relationship between the user and track.
  /// If not favorited, this operation is idempotent (no error).
  Future<void> removeFavorite(String userId, String trackId);

  /// Get count of user's favorite tracks
  ///
  /// Used for startup logic to determine which tab to show on app launch.
  /// Returns 0 if user has no favorites.
  Future<int> getFavoriteCount(String userId);
}
