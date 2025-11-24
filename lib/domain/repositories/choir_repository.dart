import '../entities/choir.dart';

/// Choir repository interface
///
/// Defines the contract for accessing choir and membership data.
/// Implementations can be for local storage, remote API, mock data, etc.
abstract class ChoirRepository {
  // ============================================================================
  // CHOIR OPERATIONS
  // ============================================================================

  /// Get all choirs for a specific user
  ///
  /// Returns only choirs where the user is a member.
  Future<List<Choir>> getChoirs(String userId);

  /// Get a specific choir by ID
  ///
  /// Returns null if choir doesn't exist or user doesn't have access.
  Future<Choir?> getChoirById(String id);

  /// Create a new choir
  ///
  /// The creator automatically becomes the owner and a member of the choir.
  /// Returns the ID of the newly created choir.
  Future<String> createChoir(String name, String ownerId);

  /// Update an existing choir
  ///
  /// Only the choir name can be updated currently.
  /// In future, other fields may be updatable.
  Future<void> updateChoir(Choir choir);

  /// Delete a choir
  ///
  /// Only the choir owner can delete a choir.
  /// This will soft-delete the choir for sync purposes.
  Future<void> deleteChoir(String id);

  // ============================================================================
  // CHOIR MEMBERSHIP OPERATIONS
  // ============================================================================

  /// Add a member to a choir
  ///
  /// Only the choir owner can add members.
  /// Throws an exception if user is already a member.
  Future<void> addMember(String choirId, String userId);

  /// Remove a member from a choir
  ///
  /// Only the choir owner can remove members.
  /// The owner cannot be removed (only way to remove owner is to delete choir).
  /// Returns true if member was removed, false if member wasn't found.
  Future<bool> removeMember(String choirId, String userId);

  /// Get all member user IDs for a choir
  ///
  /// Returns list of user IDs who are members of the choir.
  Future<List<String>> getMembers(String choirId);

  /// Check if a user is a member of a choir
  Future<bool> isMember(String choirId, String userId);

  /// Check if a user is the owner of a choir
  Future<bool> isOwner(String choirId, String userId);

  /// Get the number of members in a choir
  Future<int> getMemberCount(String choirId);
}
