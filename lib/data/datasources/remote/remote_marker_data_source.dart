import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/marker_set_model.dart';
import 'postgrest_pagination.dart';

/// Remote data source for marker set operations using Supabase
///
/// Provides CRUD operations for marker sets with cloud persistence. Individual
/// markers are not rows: they live in the `marker_sets.markers_json` payload,
/// so the set is the unit of remote I/O (and of sync conflict).
/// All operations require authentication and respect Row Level Security policies.
class RemoteMarkerDataSource {
  final SupabaseClient _supabase;

  RemoteMarkerDataSource(this._supabase);

  // ============================================================================
  // MARKER SET OPERATIONS
  // ============================================================================

  /// Get all marker sets for a track from Supabase
  ///
  /// Returns both shared marker sets and private ones created by the user.
  Future<List<MarkerSetModel>> getMarkerSetsByTrackId(
    String trackId,
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('marker_sets')
          .select('''
            id,
            track_id,
            name,
            is_shared,
            is_time_synced,
            created_by_user_id,
            created_at,
            updated_at,
            markers_json,
            deleted
          ''')
          .eq('track_id', trackId)
          .or('is_shared.eq.true,created_by_user_id.eq.$userId')
          .order('is_shared', ascending: false)
          .order('name', ascending: true) as List;

      return response
          .map((json) => MarkerSetModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch marker sets from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching marker sets: $e');
    }
  }

  /// Get marker set by ID from Supabase
  Future<MarkerSetModel?> getMarkerSetById(String id) async {
    try {
      final response = await _supabase
          .from('marker_sets')
          .select('''
            id,
            track_id,
            name,
            is_shared,
            is_time_synced,
            created_by_user_id,
            created_at,
            updated_at,
            markers_json,
            deleted
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return MarkerSetModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch marker set from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching marker set: $e');
    }
  }

  /// Create a new marker set in Supabase
  Future<void> createMarkerSet(MarkerSetModel markerSet) async {
    try {
      final body = markerSet.toJson();
      // Recompute so the payload always satisfies the
      // marker_sets_is_time_synced_matches_payload CHECK constraint even when
      // the stored flag is stale (e.g. after copying a set). This previously
      // only happened on the repository's inline push path, so the sync
      // adapter's pushes could fail permanently.
      body['is_time_synced'] = _computedIsTimeSynced(markerSet.markersJson);
      await _supabase.from('marker_sets').insert(body);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create marker set in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating marker set: $e');
    }
  }

  /// Update an existing marker set in Supabase
  Future<void> updateMarkerSet(MarkerSetModel markerSet) async {
    try {
      await _supabase
          .from('marker_sets')
          .update({
            'name': markerSet.name,
            'is_shared': markerSet.isShared,
            'is_time_synced': _computedIsTimeSynced(markerSet.markersJson),
            // Decode markersJson string to a Dart object so the Supabase client
            // serialises it as a JSON array, not a JSON string scalar.  Sending
            // the raw String causes PostgREST to store it as a JSONB scalar, which
            // makes the marker_set_payload_is_time_synced CHECK constraint throw
            // "cannot extract elements from a scalar".
            'markers_json': jsonDecode(markerSet.markersJson),
            'deleted': markerSet.deleted,
            'updated_at': markerSet.updatedAt.toUtc().toIso8601String(),
          })
          .eq('id', markerSet.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update marker set in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating marker set: $e');
    }
  }

  /// Delete a marker set from Supabase
  Future<void> deleteMarkerSet(String id, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins) and deletion is
      // never inferred from row absence.
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('marker_sets')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('id', id)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete marker set from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting marker set: $e');
    }
  }

  // ============================================================================
  // SYNC OPERATIONS - Get all data for a user
  // ============================================================================

  /// Get all marker sets accessible to a user from Supabase
  ///
  /// Returns marker sets from all tracks in all songs in all concerts
  /// in all choirs where the user is a member. Includes both shared
  /// marker sets and private ones created by the user.
  /// Used for sync operations to pull all accessible marker sets at once.
  Future<List<MarkerSetModel>> getMarkerSetsForUser(String userId) async {
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

      // Get song IDs for those concerts
      final songResponse = await fetchAllRowsChunkedIn(
          concertIds,
          (chunk) => fetchAllRows((from, to) => _supabase
              .from('songs')
              .select('id')
              .inFilter('concert_id', chunk)
              .order('id', ascending: true)
              .range(from, to)));

      if (songResponse.isEmpty) {
        return [];
      }

      final songIds = songResponse
          .map((json) => json['id'] as String)
          .toList();

      // Get track IDs for those songs
      final trackResponse = await fetchAllRowsChunkedIn(
          songIds,
          (chunk) => fetchAllRows((from, to) => _supabase
              .from('tracks')
              .select('id')
              .inFilter('song_id', chunk)
              .order('id', ascending: true)
              .range(from, to)));

      if (trackResponse.isEmpty) {
        return [];
      }

      final trackIds = trackResponse
          .map((json) => json['id'] as String)
          .toList();

      // Get marker sets for those tracks (shared OR created by user)
      final markerSetResponse = await fetchAllRowsChunkedIn(
          trackIds,
          (chunk) => fetchAllRows((from, to) => _supabase
              .from('marker_sets')
              .select('''
                id,
                track_id,
                name,
                is_shared,
                is_time_synced,
                created_by_user_id,
                created_at,
                updated_at,
                markers_json,
                deleted
              ''')
              .inFilter('track_id', chunk)
              .or('is_shared.eq.true,created_by_user_id.eq.$userId')
              .order('id', ascending: true)
              .range(from, to)));

      return markerSetResponse
          .map((json) => MarkerSetModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch marker sets for user from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching marker sets for user: $e');
    }
  }

  /// True iff every non-empty label in the payload has a non-null position_ms.
  /// Mirrors the marker_sets_is_time_synced_matches_payload CHECK constraint.
  bool _computedIsTimeSynced(String markersJson) {
    final payload = jsonDecode(markersJson) as List<dynamic>;
    return payload.every((e) {
      final entry = e as Map<String, dynamic>;
      final label = entry['label'] as String? ?? '';
      return label.isEmpty || entry['position_ms'] != null;
    });
  }
}
