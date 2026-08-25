import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/track_model.dart';

/// Remote data source for track operations using Supabase
///
/// Provides CRUD operations for tracks with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteTrackDataSource {
  final SupabaseClient _supabase;

  RemoteTrackDataSource(this._supabase);

  /// Get all tracks for a song from Supabase
  Future<List<TrackModel>> getTracksBySongId(String songId) async {
    try {
      final response = await _supabase
          .from('tracks')
          .select('''
            id,
            song_id,
            name,
            audio_url,
            storage_path,
            duration_ms,
            created_at,
            updated_at,
            deleted
          ''')
          .eq('song_id', songId)
          .order('name', ascending: true) as List;

      return response.map((json) {
        final trackJson = Map<String, dynamic>.from(json);
        // Add updated_at field if not present (required by model)
        if (!trackJson.containsKey('updated_at')) {
          trackJson['updated_at'] = trackJson['created_at'];
        }
        // Add file_path as null (local-only field)
        trackJson['file_path'] = null;
        return TrackModel.fromJson(trackJson);
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch tracks from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching tracks: $e');
    }
  }

  /// Get track by ID from Supabase
  Future<TrackModel?> getTrackById(String id) async {
    try {
      final response = await _supabase
          .from('tracks')
          .select('''
            id,
            song_id,
            name,
            audio_url,
            storage_path,
            duration_ms,
            created_at,
            updated_at,
            deleted
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final trackJson = Map<String, dynamic>.from(response);
      // Add updated_at field if not present
      if (!trackJson.containsKey('updated_at')) {
        trackJson['updated_at'] = trackJson['created_at'];
      }
      // Add file_path as null (local-only field)
      trackJson['file_path'] = null;

      return TrackModel.fromJson(trackJson);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch track from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching track: $e');
    }
  }

  /// Create a new track in Supabase
  Future<void> createTrack(TrackModel track) async {
    try {
      // Don't send file_path to Supabase (local-only column)
      final json = track.toJson();
      json.remove('file_path');

      await _supabase.from('tracks').insert(json);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create track in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating track: $e');
    }
  }

  /// Update an existing track in Supabase
  Future<void> updateTrack(TrackModel track) async {
    try {
      await _supabase
          .from('tracks')
          .update({
            'name': track.name,
            'audio_url': track.audioUrl,
            'storage_path': track.storagePath,
            'duration_ms': track.durationMs,
            'deleted': track.deleted,
            'updated_at': track.updatedAt.toUtc().toIso8601String(),
          })
          .eq('id', track.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update track in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating track: $e');
    }
  }

  /// Delete a track from Supabase
  Future<void> deleteTrack(String id, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins) and deletion is
      // never inferred from row absence.
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('tracks')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('id', id)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete track from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting track: $e');
    }
  }

  /// Get all tracks for a user from Supabase
  ///
  /// Returns tracks from all songs in all concerts in all choirs
  /// where the user is a member.
  /// Used for sync operations to pull all accessible tracks at once.
  Future<List<TrackModel>> getTracksForUser(String userId) async {
    try {
      // First get choir IDs where user is a member
      final memberResponse = await _supabase
          .from('choir_members')
          .select('choir_id')
          .eq('user_id', userId)
          .eq('deleted', false) as List;

      if (memberResponse.isEmpty) {
        return [];
      }

      final choirIds = memberResponse
          .map((json) => json['choir_id'] as String)
          .toList();

      // Get concert IDs for those choirs
      final concertResponse = await _supabase
          .from('concerts')
          .select('id')
          .inFilter('choir_id', choirIds) as List;

      if (concertResponse.isEmpty) {
        return [];
      }

      final concertIds = concertResponse
          .map((json) => json['id'] as String)
          .toList();

      // Get song IDs for those concerts
      final songResponse = await _supabase
          .from('songs')
          .select('id')
          .inFilter('concert_id', concertIds) as List;

      if (songResponse.isEmpty) {
        return [];
      }

      final songIds = songResponse
          .map((json) => json['id'] as String)
          .toList();

      // Get tracks for those songs
      final trackResponse = await _supabase
          .from('tracks')
          .select('''
            id,
            song_id,
            name,
            audio_url,
            storage_path,
            duration_ms,
            created_at,
            updated_at,
            deleted
          ''')
          .inFilter('song_id', songIds)
          .order('name', ascending: true) as List;

      return trackResponse.map((json) {
        final trackJson = Map<String, dynamic>.from(json);
        // Add updated_at field if not present (required by model)
        if (!trackJson.containsKey('updated_at')) {
          trackJson['updated_at'] = trackJson['created_at'];
        }
        // Add file_path as null (local-only field)
        trackJson['file_path'] = null;
        return TrackModel.fromJson(trackJson);
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch tracks for user from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching tracks for user: $e');
    }
  }
}
