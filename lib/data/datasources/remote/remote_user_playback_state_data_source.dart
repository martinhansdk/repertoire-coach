import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_playback_state_model.dart';

/// Remote data source for user playback state operations using Supabase
///
/// Provides CRUD operations for playback states with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
/// Playback states are private per-user.
class RemoteUserPlaybackStateDataSource {
  final SupabaseClient _supabase;

  RemoteUserPlaybackStateDataSource(this._supabase);

  /// Get playback state for a user, song, and track from Supabase
  ///
  /// Returns null if no state exists.
  Future<UserPlaybackStateModel?> getPlaybackState(
    String userId,
    String songId,
    String trackId,
  ) async {
    try {
      final response = await _supabase
          .from('playback_states')
          .select('''
            user_id,
            song_id,
            track_id,
            position_ms,
            updated_at
          ''')
          .eq('user_id', userId)
          .eq('song_id', songId)
          .eq('track_id', trackId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserPlaybackStateModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch playback state from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching playback state: $e');
    }
  }

  /// Get all playback states for a user and song from Supabase
  Future<List<UserPlaybackStateModel>> getPlaybackStatesBySongId(
    String userId,
    String songId,
  ) async {
    try {
      final response = await _supabase
          .from('playback_states')
          .select('''
            user_id,
            song_id,
            track_id,
            position_ms,
            updated_at
          ''')
          .eq('user_id', userId)
          .eq('song_id', songId) as List;

      return response
          .map((json) => UserPlaybackStateModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch playback states from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching playback states: $e');
    }
  }

  /// Save or update playback state in Supabase
  ///
  /// Uses upsert to create or update the state.
  Future<void> savePlaybackState(UserPlaybackStateModel state) async {
    try {
      // Don't send the id field - use composite primary key
      final json = state.toJson();
      json.remove('id');

      await _supabase.from('playback_states').upsert(
            json,
            onConflict: 'user_id,song_id,track_id',
          );
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to save playback state to Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error saving playback state: $e');
    }
  }

  /// Delete playback state from Supabase
  Future<void> deletePlaybackState(
    String userId,
    String songId,
    String trackId,
  ) async {
    try {
      await _supabase
          .from('playback_states')
          .delete()
          .eq('user_id', userId)
          .eq('song_id', songId)
          .eq('track_id', trackId);
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to delete playback state from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting playback state: $e');
    }
  }

  /// Delete all playback states for a song from Supabase
  Future<void> deletePlaybackStatesBySongId(String userId, String songId) async {
    try {
      await _supabase
          .from('playback_states')
          .delete()
          .eq('user_id', userId)
          .eq('song_id', songId);
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to delete playback states from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting playback states: $e');
    }
  }
}
