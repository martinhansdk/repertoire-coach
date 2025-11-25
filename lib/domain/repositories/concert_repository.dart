import '../entities/concert.dart';

/// Concert repository interface
///
/// Defines the contract for accessing concert data.
/// Implementations can be for local storage, remote API, mock data, etc.
abstract class ConcertRepository {
  /// Get all concerts for the current user across all their choirs
  ///
  /// Concerts are automatically sorted by date:
  /// - Upcoming concerts first (soonest to farthest)
  /// - Past concerts after (most recent to oldest)
  Future<List<Concert>> getConcerts();

  /// Get concerts for a specific choir
  Future<List<Concert>> getConcertsByChoir(String choirId);

  /// Get a specific concert by ID
  Future<Concert?> getConcertById(String concertId);

  /// Create a new concert
  ///
  /// Throws an exception if a concert with the same ID already exists.
  Future<void> createConcert(Concert concert);

  /// Update an existing concert
  ///
  /// Returns true if update succeeded, false if concert not found.
  Future<bool> updateConcert(Concert concert);

  /// Delete a concert (soft delete)
  ///
  /// Concert is marked as deleted but not removed from database.
  Future<void> deleteConcert(String concertId);
}
