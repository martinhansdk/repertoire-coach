import '../entities/song.dart';

/// Song repository interface
///
/// Defines the contract for accessing song data.
/// Implementations can be for local storage, remote API, mock data, etc.
abstract class SongRepository {
  /// Get all songs for a specific concert
  ///
  /// Returns songs in the order they were created (chronological).
  Future<List<Song>> getSongsByConcert(String concertId);

  /// Get a specific song by ID
  Future<Song?> getSongById(String songId);

  /// Create a new song
  ///
  /// Throws an exception if a song with the same ID already exists.
  Future<void> createSong(Song song);

  /// Update an existing song
  ///
  /// Returns true if update succeeded, false if song not found.
  Future<bool> updateSong(Song song);

  /// Delete a song (soft delete)
  ///
  /// Song is marked as deleted but not removed from database.
  Future<void> deleteSong(String songId);
}
