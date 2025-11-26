import '../entities/track.dart';

/// Track repository interface
///
/// Defines the contract for accessing track data.
/// Implementations can be for local storage, remote API, mock data, etc.
abstract class TrackRepository {
  /// Get all tracks for a specific song
  ///
  /// Returns tracks in the order they were created (chronological).
  Future<List<Track>> getTracksBySong(String songId);

  /// Get a specific track by ID
  Future<Track?> getTrackById(String trackId);

  /// Create a new track
  ///
  /// Throws an exception if a track with the same ID already exists.
  Future<void> createTrack(Track track);

  /// Update an existing track
  ///
  /// Returns true if update succeeded, false if track not found.
  Future<bool> updateTrack(Track track);

  /// Delete a track (soft delete)
  ///
  /// Track is marked as deleted but not removed from database.
  Future<void> deleteTrack(String trackId);
}
