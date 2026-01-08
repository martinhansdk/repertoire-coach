import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/concert_model.dart';

/// Remote data source for concert operations using Supabase
///
/// Provides CRUD operations for concerts with cloud persistence.
/// All operations require authentication and respect Row Level Security policies.
class RemoteConcertDataSource {
  final SupabaseClient _supabase;

  RemoteConcertDataSource(this._supabase);

  /// Get all concerts for a user from Supabase
  ///
  /// Returns concerts from all choirs where the user is a member.
  /// Sorted by date (upcoming first, then past in reverse order).
  Future<List<ConcertModel>> getConcerts(String userId) async {
    try {
      // First get choir IDs where user is a member
      final memberResponse = await _supabase
          .from('choir_members')
          .select('choir_id')
          .eq('user_id', userId);

      if (memberResponse == null || (memberResponse as List).isEmpty) {
        return [];
      }

      final choirIds = (memberResponse as List)
          .map((json) => json['choir_id'] as String)
          .toList();

      // Get concerts for those choirs with choir names
      final concertResponse = await _supabase
          .from('concerts')
          .select('''
            id,
            choir_id,
            name,
            concert_date,
            created_at,
            choirs!inner(name)
          ''')
          .in_('choir_id', choirIds)
          .order('concert_date', ascending: true);

      if (concertResponse == null) {
        return [];
      }

      final concerts = (concertResponse as List).map((json) {
        final concertJson = Map<String, dynamic>.from(json);
        // Extract choir name from nested choirs object
        concertJson['choir_name'] = json['choirs']['name'];
        concertJson.remove('choirs');
        return ConcertModel.fromJson(concertJson);
      }).toList();

      return concerts;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch concerts from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching concerts: $e');
    }
  }

  /// Get concert by ID from Supabase
  Future<ConcertModel?> getConcertById(String id) async {
    try {
      final response = await _supabase
          .from('concerts')
          .select('''
            id,
            choir_id,
            name,
            concert_date,
            created_at,
            choirs!inner(name)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final concertJson = Map<String, dynamic>.from(response);
      concertJson['choir_name'] = response['choirs']['name'];
      concertJson.remove('choirs');

      return ConcertModel.fromJson(concertJson);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch concert from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching concert: $e');
    }
  }

  /// Create a new concert in Supabase
  Future<void> createConcert(ConcertModel concert) async {
    try {
      await _supabase.from('concerts').insert(concert.toJson());
    } on PostgrestException catch (e) {
      throw Exception('Failed to create concert in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating concert: $e');
    }
  }

  /// Update an existing concert in Supabase
  Future<void> updateConcert(ConcertModel concert) async {
    try {
      await _supabase
          .from('concerts')
          .update({
            'name': concert.name,
            'concert_date': concert.concertDate.toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', concert.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update concert in Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating concert: $e');
    }
  }

  /// Delete a concert from Supabase
  Future<void> deleteConcert(String id) async {
    try {
      await _supabase.from('concerts').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete concert from Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting concert: $e');
    }
  }
}
