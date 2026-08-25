import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/choir_member_model.dart';
import '../../models/choir_model.dart';

/// Remote data source for choir and membership operations using Supabase
///
/// Provides CRUD operations for choirs and choir members with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteChoirDataSource {
  final SupabaseClient _supabase;

  RemoteChoirDataSource(this._supabase);

  // ============================================================================
  // CHOIR OPERATIONS
  // ============================================================================

  /// Get all choirs for a user from Supabase
  ///
  /// Returns choirs where the user is a member.
  /// Respects RLS policies (users can only see choirs they're members of).
  Future<List<ChoirModel>> getChoirs(String userId) async {
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

      // Then get the choir details
      final choirResponse = await _supabase
          .from('choirs')
          .select('''
            id,
            name,
            owner_id,
            created_at,
            updated_at,
            deleted
          ''')
          .inFilter('id', choirIds) as List;

      final choirs = choirResponse
          .map((json) => ChoirModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return choirs;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch choirs from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching choirs: $e');
    }
  }

  /// Get choir by ID from Supabase
  ///
  /// Returns null if choir doesn't exist or user doesn't have access.
  /// Respects RLS policies.
  Future<ChoirModel?> getChoirById(String id) async {
    try {
      final response = await _supabase
          .from('choirs')
          .select('''
            id,
            name,
            owner_id,
            created_at,
            updated_at,
            deleted
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return ChoirModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch choir from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching choir: $e');
    }
  }

  /// Create a new choir in Supabase
  ///
  /// Creates the choir and automatically adds the creator as a member.
  /// This must be done in a transaction to ensure consistency.
  Future<void> createChoir(ChoirModel choir, String creatorUserId) async {
    try {
      // Insert the choir
      await _supabase.from('choirs').insert(choir.toJson());

      // Add creator as a member
      final member = ChoirMemberModel(
        choirId: choir.id,
        userId: creatorUserId,
        joinedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase.from('choir_members').insert(member.toJson());
    } on PostgrestException catch (e) {
      throw Exception('Failed to create choir in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating choir: $e');
    }
  }

  /// Update an existing choir in Supabase
  ///
  /// Only choir owners can update (enforced by RLS policies).
  Future<void> updateChoir(ChoirModel choir) async {
    try {
      await _supabase
          .from('choirs')
          .update({
            'name': choir.name,
            'deleted': choir.deleted,
            'updated_at': choir.updatedAt.toUtc().toIso8601String(),
          })
          .eq('id', choir.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update choir in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating choir: $e');
    }
  }

  /// Delete a choir from Supabase
  ///
  /// Only choir owners can delete (enforced by RLS policies).
  /// Cascade deletes will remove all related data (concerts, songs, etc.).
  Future<void> deleteChoir(String id, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins) and deletion is
      // never inferred from row absence.
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('choirs')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('id', id)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete choir from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting choir: $e');
    }
  }

  // ============================================================================
  // CHOIR MEMBERSHIP OPERATIONS
  // ============================================================================

  /// Add a member to a choir in Supabase
  ///
  /// Only choir owners can add members (enforced by RLS policies).
  Future<void> addMember(
      String choirId, String userId, DateTime updatedAt) async {
    try {
      // Upsert (not insert): re-adding a previously removed member must clear
      // the tombstone instead of failing with a duplicate-key error.
      await _supabase.from('choir_members').upsert({
        'choir_id': choirId,
        'user_id': userId,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': false,
      }, onConflict: 'choir_id,user_id');
    } on PostgrestException catch (e) {
      throw Exception('Failed to add member in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding member: $e');
    }
  }

  /// Remove a member from a choir in Supabase
  ///
  /// Only choir owners can remove members (enforced by RLS policies).
  Future<void> removeMember(
      String choirId, String userId, DateTime deletedAt) async {
    try {
      // Soft delete: tombstones sync like edits (newest wins).
      // The lte filter enforces newest-wins server-side: if the remote row is
      // newer than the deletion, 0 rows match and the tombstone is not planted.
      final deletedAtIso = deletedAt.toUtc().toIso8601String();
      await _supabase
          .from('choir_members')
          .update({
            'deleted': true,
            'updated_at': deletedAtIso,
          })
          .eq('choir_id', choirId)
          .eq('user_id', userId)
          .lte('updated_at', deletedAtIso);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove member from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error removing member: $e');
    }
  }

  /// Get all member user IDs for a choir from Supabase
  ///
  /// Returns list of user IDs who are members of the choir.
  Future<List<String>> getChoirMembers(String choirId) async {
    try {
      final response = await _supabase
          .from('choir_members')
          .select('user_id')
          .eq('choir_id', choirId) as List;

      return response
          .map((json) => json['user_id'] as String)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch choir members from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching choir members: $e');
    }
  }

  /// Check if a user is a member of a choir in Supabase
  Future<bool> isMember(String choirId, String userId) async {
    try {
      final response = await _supabase
          .from('choir_members')
          .select('user_id')
          .eq('choir_id', choirId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to check membership in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error checking membership: $e');
    }
  }

  /// Check if a user is the owner of a choir in Supabase
  Future<bool> isOwner(String choirId, String userId) async {
    try {
      final response = await _supabase
          .from('choirs')
          .select('owner_id')
          .eq('id', choirId)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      return response['owner_id'] == userId;
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to check choir ownership in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error checking ownership: $e');
    }
  }

  /// Get the number of members in a choir from Supabase
  Future<int> getMemberCount(String choirId) async {
    try {
      final response = await _supabase
          .from('choir_members')
          .select('user_id')
          .eq('choir_id', choirId)
          .count();

      // Return the count from the response
      return response.count;
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to get member count from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting member count: $e');
    }
  }

  // ============================================================================
  // SYNC OPERATIONS - Get all data for a user
  // ============================================================================

  /// Get all choir members from all choirs the user is a member of
  ///
  /// Returns ChoirMemberModel objects for all members in all user's choirs.
  /// Used for sync operations to pull all choir membership data at once.
  Future<List<ChoirMemberModel>> getChoirMembersForUser(String userId) async {
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

      // Get all members for those choirs
      final allMembersResponse = await _supabase
          .from('choir_members')
          .select('''
            choir_id,
            user_id,
            joined_at,
            updated_at,
            deleted
          ''')
          .inFilter('choir_id', choirIds) as List;

      return allMembersResponse
          .map((json) => ChoirMemberModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
          'Failed to fetch choir members for user from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching choir members for user: $e');
    }
  }
}
