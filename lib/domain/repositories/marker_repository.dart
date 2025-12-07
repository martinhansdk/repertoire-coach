import '../entities/marker.dart';
import '../entities/marker_set.dart';

/// Marker repository interface
///
/// Defines the contract for accessing marker and marker set data.
/// Implementations can be for local storage, remote API, mock data, etc.
abstract class MarkerRepository {
  // ==================== MarkerSet Operations ====================

  /// Get all marker sets for a specific track
  ///
  /// Returns marker sets that are either shared OR created by the specified user.
  /// For local-first mode, userId is optional and defaults to getting all sets.
  /// Returns marker sets ordered by: shared first, then by name.
  Future<List<MarkerSet>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  });

  /// Get a specific marker set by ID
  Future<MarkerSet?> getMarkerSetById(String markerSetId);

  /// Create a new marker set
  ///
  /// Throws an exception if a marker set with the same ID already exists.
  Future<void> createMarkerSet(MarkerSet markerSet);

  /// Update an existing marker set
  ///
  /// Returns true if update succeeded, false if marker set not found.
  Future<bool> updateMarkerSet(MarkerSet markerSet);

  /// Delete a marker set (soft delete)
  ///
  /// Marker set is marked as deleted but not removed from database.
  /// Also deletes all markers belonging to this set.
  Future<void> deleteMarkerSet(String markerSetId);

  // ==================== Marker Operations ====================

  /// Get all markers for a specific marker set
  ///
  /// Returns markers ordered by their display order.
  Future<List<Marker>> getMarkersByMarkerSet(String markerSetId);

  /// Get a specific marker by ID
  Future<Marker?> getMarkerById(String markerId);

  /// Create a new marker
  ///
  /// Throws an exception if a marker with the same ID already exists.
  Future<void> createMarker(Marker marker);

  /// Update an existing marker
  ///
  /// Returns true if update succeeded, false if marker not found.
  Future<bool> updateMarker(Marker marker);

  /// Delete a marker (soft delete)
  ///
  /// Marker is marked as deleted but not removed from database.
  Future<void> deleteMarker(String markerId);
}
