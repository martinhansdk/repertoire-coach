import '../../domain/entities/concert.dart';
import '../../domain/repositories/concert_repository.dart';
import '../datasources/local/local_concert_data_source.dart';

/// Concert repository implementation using local Drift database
///
/// Provides offline-first data persistence with SQLite.
/// All data is stored locally and works without internet connection.
/// Future versions will add cloud sync with Supabase.
class ConcertRepositoryImpl implements ConcertRepository {
  final LocalConcertDataSource _localDataSource;

  ConcertRepositoryImpl(this._localDataSource);

  @override
  Future<List<Concert>> getConcerts() async {
    // Get all concerts from local database (already sorted)
    final concertModels = await _localDataSource.getConcerts();

    // Convert to domain entities
    return concertModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Concert>> getConcertsByChoir(String choirId) async {
    final concerts = await getConcerts();

    // Filter by choir ID
    return concerts.where((c) => c.choirId == choirId).toList();
  }

  @override
  Future<Concert?> getConcertById(String concertId) async {
    final concertModel = await _localDataSource.getConcertById(concertId);

    return concertModel?.toEntity();
  }
}
