import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/song_model.dart';

/// Remote data source for song operations using Supabase
///
/// Provides CRUD operations for songs with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteSongDataSource {
  final SupabaseClient _supabase;

  RemoteSongDataSource(this._supabase);

  /// Get all songs for a concert from Supabase
  Future<List<SongModel>> getSongsByConcertId(String concertId) async {
    try {
      final response = await _supabase
          .from('songs')
          .select('''
            id,
            concert_id,
            title,
            created_at,
            updated_at
          ''')
          .eq('concert_id', concertId)
          .order('title', ascending: true);

      if (response == null) {
        return [];
      }

      return (response as List)
          .map((json) => SongModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch songs from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching songs: $e');
    }
  }

  /// Get song by ID from Supabase
  Future<SongModel?> getSongById(String id) async {
    try {
      final response = await _supabase
          .from('songs')
          .select('''
            id,
            concert_id,
            title,
            created_at,
            updated_at
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return SongModel.fromJson(response as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch song from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching song: $e');
    }
  }

  /// Create a new song in Supabase
  Future<void> createSong(SongModel song) async {
    try {
      await _supabase.from('songs').insert(song.toJson());
    } on PostgrestException catch (e) {
      throw Exception('Failed to create song in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating song: $e');
    }
  }

  /// Update an existing song in Supabase
  Future<void> updateSong(SongModel song) async {
    try {
      await _supabase
          .from('songs')
          .update({
            'title': song.title,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', song.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update song in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating song: $e');
    }
  }

  /// Delete a song from Supabase
  Future<void> deleteSong(String id) async {
    try {
      await _supabase.from('songs').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete song from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting song: $e');
    }
  }
}
