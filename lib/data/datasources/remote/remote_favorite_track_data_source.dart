import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/favorite_track_model.dart';
import 'postgrest_pagination.dart';

/// Remote data source for favorite track operations using Supabase
///
/// Provides operations for user's favorite tracks with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteFavoriteTrackDataSource {
  final SupabaseClient _supabase;

  RemoteFavoriteTrackDataSource(this._supabase);

  /// Get all favorite tracks for a user from Supabase
  ///
  /// Returns favorites with full Track objects.
  /// Sorted by added_at descending (most recent first).
  Future<List<FavoriteTrackModel>> getFavorites(String userId) async {
    try {
      // Ordered by unique track_id (unique per user): pagination needs a
      // total order; the UI orders its own reads from local.
      final response = await fetchAllRows((from, to) => _supabase
          .from('favorite_tracks')
          .select('''
            track_id,
            song_id,
            added_at,
            updated_at,
            deleted,
            tracks!inner(
              name,
              audio_url,
              storage_path,
              duration_ms,
              created_at
            )
          ''')
          .eq('user_id', userId)
          .order('track_id', ascending: true)
          .range(from, to));

      return response
          .map<FavoriteTrackModel>((json) => FavoriteTrackModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch favorites from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching favorites: $e');
    }
  }

  /// Check if a track is favorited by a user
  ///
  /// Returns true if the favorite exists, false otherwise.
  Future<bool> isFavorite(String userId, String trackId) async {
    try {
      final response = await _supabase
          .from('favorite_tracks')
          .select('user_id')
          .eq('user_id', userId)
          .eq('track_id', trackId)
          .maybeSingle();

      return response != null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to check favorite status: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error checking favorite: $e');
    }
  }

  /// Add a track to user's favorites in Supabase
  ///
  /// Creates a favorite relationship. Idempotent - no error if already favorited.
  Future<void> addFavorite(
    String userId,
    String trackId,
    String songId,
    DateTime updatedAt,
  ) async {
    try {
      // Upsert clears any tombstone when a favorite is re-added.
      await _supabase.from('favorite_tracks').upsert({
        'user_id': userId,
        'track_id': trackId,
        'song_id': songId,
        'added_at': updatedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': false,
      }, onConflict: 'user_id,track_id');
    } on PostgrestException catch (e) {
      throw Exception('Failed to add favorite to Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding favorite: $e');
    }
  }

  /// Remove a track from user's favorites in Supabase
  ///
  /// Deletes the favorite relationship. Idempotent - no error if not favorited.
  Future<void> removeFavorite(
      String userId, String trackId, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins).
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('favorite_tracks')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('user_id', userId)
          .eq('track_id', trackId)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove favorite from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error removing favorite: $e');
    }
  }

  /// Get all favorites for sync (lightweight, no track JOIN)
  ///
  /// Returns just (trackId, songId, addedAt) tuples for sync comparison.
  /// Avoids the expensive JOIN to tracks table.
  Future<List<({String trackId, String songId, DateTime addedAt})>>
      getFavoritesForSync(String userId) async {
    try {
      final response = await _supabase
          .from('favorite_tracks')
          .select('track_id, song_id, added_at')
          .eq('user_id', userId) as List;

      return response.map((json) {
        return (
          trackId: json['track_id'] as String,
          songId: json['song_id'] as String,
          addedAt: DateTime.parse(json['added_at'] as String),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch favorites for sync from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching favorites for sync: $e');
    }
  }

  /// Get count of favorite tracks for a user
  ///
  /// Used for startup logic to determine which tab to show.
  Future<int> getFavoriteCount(String userId) async {
    try {
      final response = await _supabase
          .from('favorite_tracks')
          .select('user_id')
          .eq('user_id', userId)
          .count();

      return response.count;
    } on PostgrestException catch (e) {
      throw Exception('Failed to get favorite count: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting favorite count: $e');
    }
  }
}
