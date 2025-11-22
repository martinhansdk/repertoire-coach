import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/concert_repository_impl.dart';
import '../../domain/entities/concert.dart';
import '../../domain/repositories/concert_repository.dart';

/// Provider for the concert repository
///
/// This provides a single instance of the repository throughout the app.
/// In future, this can be easily swapped for a real Supabase implementation.
final concertRepositoryProvider = Provider<ConcertRepository>((ref) {
  return ConcertRepositoryImpl();
});

/// Provider for the list of concerts
///
/// Fetches all concerts from the repository and automatically sorts them
/// by date (upcoming first, then past).
final concertsProvider = FutureProvider<List<Concert>>((ref) async {
  final repository = ref.watch(concertRepositoryProvider);
  return await repository.getConcerts();
});

/// Provider for concerts filtered by a specific choir
///
/// Usage: ref.watch(concertsByChoirProvider('choir-id'))
final concertsByChoirProvider =
    FutureProvider.family<List<Concert>, String>((ref, choirId) async {
  final repository = ref.watch(concertRepositoryProvider);
  return await repository.getConcertsByChoir(choirId);
});

/// Provider for a single concert by ID
///
/// Usage: ref.watch(concertByIdProvider('concert-id'))
final concertByIdProvider =
    FutureProvider.family<Concert?, String>((ref, concertId) async {
  final repository = ref.watch(concertRepositoryProvider);
  return await repository.getConcertById(concertId);
});
