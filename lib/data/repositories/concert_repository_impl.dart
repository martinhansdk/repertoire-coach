import '../../domain/entities/concert.dart';
import '../../domain/repositories/concert_repository.dart';
import '../models/concert_model.dart';

/// Mock implementation of ConcertRepository
///
/// Returns hardcoded concert data for demonstration.
/// In future, this will be replaced with actual Supabase integration.
class ConcertRepositoryImpl implements ConcertRepository {
  /// Mock concert data
  static final List<Concert> _mockConcerts = [
    ConcertModel(
      id: '1',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Spring Concert 2025',
      concertDate: DateTime(2025, 4, 15),
      createdAt: DateTime(2024, 12, 1),
    ),
    ConcertModel(
      id: '2',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Christmas Concert 2024',
      concertDate: DateTime(2024, 12, 20),
      createdAt: DateTime(2024, 10, 1),
    ),
    ConcertModel(
      id: '3',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Summer Festival',
      concertDate: DateTime(2025, 6, 10),
      createdAt: DateTime(2024, 11, 15),
    ),
    ConcertModel(
      id: '4',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Autumn Recital',
      concertDate: DateTime(2024, 10, 5),
      createdAt: DateTime(2024, 8, 1),
    ),
    ConcertModel(
      id: '5',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Winter Showcase',
      concertDate: DateTime(2025, 2, 14),
      createdAt: DateTime(2024, 11, 20),
    ),
  ];

  @override
  Future<List<Concert>> getConcerts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Sort concerts by date:
    // - Upcoming concerts first (soonest to farthest)
    // - Past concerts after (most recent to oldest)
    final now = DateTime.now();
    final sorted = List<Concert>.from(_mockConcerts)
      ..sort((a, b) {
        final aIsUpcoming = a.concertDate.isAfter(now);
        final bIsUpcoming = b.concertDate.isAfter(now);

        // Both upcoming: sort ascending (soonest first)
        if (aIsUpcoming && bIsUpcoming) {
          return a.concertDate.compareTo(b.concertDate);
        }

        // Both past: sort descending (most recent first)
        if (!aIsUpcoming && !bIsUpcoming) {
          return b.concertDate.compareTo(a.concertDate);
        }

        // One upcoming, one past: upcoming comes first
        return aIsUpcoming ? -1 : 1;
      });

    return sorted;
  }

  @override
  Future<List<Concert>> getConcertsByChoir(String choirId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final concerts = await getConcerts();
    return concerts.where((c) => c.choirId == choirId).toList();
  }

  @override
  Future<Concert?> getConcertById(String concertId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      return _mockConcerts.firstWhere((c) => c.id == concertId);
    } catch (_) {
      return null;
    }
  }
}
