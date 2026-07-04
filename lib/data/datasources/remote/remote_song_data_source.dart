import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/song_model.dart';
import 'postgrest_pagination.dart';

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
            updated_at,
            deleted
          ''')
          .eq('concert_id', concertId)
          .order('title', ascending: true) as List;

      return response
          .map((json) => SongModel.fromJson(json))
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
            updated_at,
            deleted
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return SongModel.fromJson(response);
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
            'deleted': song.deleted,
            'updated_at': song.updatedAt.toUtc().toIso8601String(),
          })
          .eq('id', song.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update song in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating song: $e');
    }
  }

  /// Delete a song from Supabase
  Future<void> deleteSong(String id, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins) and deletion is
      // never inferred from row absence.
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('songs')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('id', id)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete song from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting song: $e');
    }
  }

  /// Get all songs for a user from Supabase
  ///
  /// Returns songs from all concerts in all choirs where the user is a member.
  /// Used for sync operations to pull all accessible songs at once.
  Future<List<SongModel>> getSongsForUser(String userId) async {
    try {
      // First get choir IDs where user is a member
      final memberResponse = await fetchAllRows((from, to) => _supabase
          .from('choir_members')
          .select('choir_id')
          .eq('user_id', userId)
          .eq('deleted', false)
          .order('choir_id', ascending: true)
          .range(from, to));

      if (memberResponse.isEmpty) {
        return [];
      }

      final choirIds = memberResponse
          .map((json) => json['choir_id'] as String)
          .toList();

      // Get concert IDs for those choirs
      final concertResponse = await fetchAllRowsChunkedIn(
          choirIds,
          (chunk) => fetchAllRows((from, to) => _supabase
              .from('concerts')
              .select('id')
              .inFilter('choir_id', chunk)
              .order('id', ascending: true)
              .range(from, to)));

      if (concertResponse.isEmpty) {
        return [];
      }

      final concertIds = concertResponse
          .map((json) => json['id'] as String)
          .toList();

      // Get songs for those concerts
      // Ordered by unique id: pagination needs a total order, and sync
      // consumers don't care about display order (the UI reads from local).
      final songResponse = await fetchAllRowsChunkedIn(
          concertIds,
          (chunk) => fetchAllRows((from, to) => _supabase
              .from('songs')
              .select('''
                id,
                concert_id,
                title,
                created_at,
                updated_at,
                deleted
              ''')
              .inFilter('concert_id', chunk)
              .order('id', ascending: true)
              .range(from, to)));

      return songResponse
          .map((json) => SongModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch songs for user from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching songs for user: $e');
    }
  }
}
