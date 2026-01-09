import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/marker_model.dart';
import '../../models/marker_set_model.dart';

/// Remote data source for marker and marker set operations using Supabase
///
/// Provides CRUD operations for markers and marker sets with cloud persistence.
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
            created_by_user_id,
            created_at,
            updated_at
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
            created_by_user_id,
            created_at,
            updated_at
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
      await _supabase.from('marker_sets').insert(markerSet.toJson());
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
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', markerSet.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update marker set in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating marker set: $e');
    }
  }

  /// Delete a marker set from Supabase
  Future<void> deleteMarkerSet(String id) async {
    try {
      await _supabase.from('marker_sets').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete marker set from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting marker set: $e');
    }
  }

  // ============================================================================
  // MARKER OPERATIONS
  // ============================================================================

  /// Get all markers for a marker set from Supabase
  Future<List<MarkerModel>> getMarkersBySetId(String markerSetId) async {
    try {
      final response = await _supabase
          .from('markers')
          .select('''
            id,
            marker_set_id,
            label,
            position_ms,
            display_order,
            created_at
          ''')
          .eq('marker_set_id', markerSetId)
          .order('display_order', ascending: true) as List;

      return response
          .map((json) => MarkerModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch markers from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching markers: $e');
    }
  }

  /// Get marker by ID from Supabase
  Future<MarkerModel?> getMarkerById(String id) async {
    try {
      final response = await _supabase
          .from('markers')
          .select('''
            id,
            marker_set_id,
            label,
            position_ms,
            display_order,
            created_at
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return MarkerModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch marker from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching marker: $e');
    }
  }

  /// Create a new marker in Supabase
  Future<void> createMarker(MarkerModel marker) async {
    try {
      await _supabase.from('markers').insert(marker.toJson());
    } on PostgrestException catch (e) {
      throw Exception('Failed to create marker in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating marker: $e');
    }
  }

  /// Update an existing marker in Supabase
  Future<void> updateMarker(MarkerModel marker) async {
    try {
      await _supabase
          .from('markers')
          .update({
            'label': marker.label,
            'position_ms': marker.positionMs,
            'display_order': marker.order,
          })
          .eq('id', marker.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update marker in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating marker: $e');
    }
  }

  /// Delete a marker from Supabase
  Future<void> deleteMarker(String id) async {
    try {
      await _supabase.from('markers').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete marker from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting marker: $e');
    }
  }

  /// Delete all markers for a marker set from Supabase
  Future<void> deleteMarkersBySetId(String markerSetId) async {
    try {
      await _supabase
          .from('markers')
          .delete()
          .eq('marker_set_id', markerSetId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete markers from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting markers: $e');
    }
  }
}
