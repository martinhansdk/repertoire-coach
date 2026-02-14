import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/favorite_track_model.dart';

/// Remote data source for favorite track operations using Supabase
///
/// Provides operations for user's favorite tracks with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteFavoriteTrackDataSource {
  final SupabaseClient _supabase;

  RemoteFavoriteTrackDataSource(this._supabase);

  /// Get all favorite tracks for a user from Supabase
  ///
  /// Returns favorites with denormalized data (track name, song title, choir name).
  /// Sorted by added_at descending (most recent first).
  Future<List<FavoriteTrackModel>> getFavorites(String userId) async {
    try {
      print('[RemoteFavoriteTrackDataSource] Fetching favorites for user: $userId');

      final response = await _supabase
          .from('favorite_tracks')
          .select('''
            user_id,
            track_id,
            song_id,
            added_at,
            tracks!inner(
              name,
              audio_url,
              duration_ms
            ),
            songs!inner(
              title,
              concerts!inner(
                choirs!inner(name)
              )
            )
          ''')
          .eq('user_id', userId)
          .order('added_at', ascending: false) as List;

      print('[RemoteFavoriteTrackDataSource] Received ${response.length} favorites from Supabase');

      final favorites = response.map((json) {
        final favoriteJson = Map<String, dynamic>.from(json);

        // Extract track data
        final trackData = json['tracks'];
        final audioUrl = trackData['audio_url'];
        favoriteJson['track_name'] = trackData['name'];
        favoriteJson['audio_url'] = audioUrl;
        favoriteJson['duration_ms'] = trackData['duration_ms'];

        print('[RemoteFavoriteTrackDataSource] Track: ${trackData['name']}, audioUrl: $audioUrl');

        // Extract song title
        final songData = json['songs'];
        favoriteJson['song_title'] = songData['title'];

        // Extract choir name (nested: songs -> concerts -> choirs)
        final concertData = songData['concerts'];
        final choirData = concertData['choirs'];
        favoriteJson['choir_name'] = choirData['name'];

        // Remove nested objects
        favoriteJson.remove('tracks');
        favoriteJson.remove('songs');

        return FavoriteTrackModel.fromJson(favoriteJson);
      }).toList();

      print('[RemoteFavoriteTrackDataSource] Returning ${favorites.length} favorites');
      return favorites;
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
  ) async {
    try {
      await _supabase.from('favorite_tracks').upsert({
        'user_id': userId,
        'track_id': trackId,
        'song_id': songId,
        'added_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to add favorite to Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding favorite: $e');
    }
  }

  /// Remove a track from user's favorites in Supabase
  ///
  /// Deletes the favorite relationship. Idempotent - no error if not favorited.
  Future<void> removeFavorite(String userId, String trackId) async {
    try {
      await _supabase
          .from('favorite_tracks')
          .delete()
          .eq('user_id', userId)
          .eq('track_id', trackId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove favorite from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error removing favorite: $e');
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
