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
            created_at
          ''')
          .eq('song_id', songId)
          .order('name', ascending: true);

      if (response == null) {
        return [];
      }

      return (response as List).map((json) {
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
            created_at
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
      // Don't send file_path or updated_at to Supabase
      final json = track.toJson();
      json.remove('file_path');
      json.remove('updated_at');

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
          })
          .eq('id', track.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update track in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating track: $e');
    }
  }

  /// Delete a track from Supabase
  Future<void> deleteTrack(String id) async {
    try {
      await _supabase.from('tracks').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete track from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting track: $e');
    }
  }
}
