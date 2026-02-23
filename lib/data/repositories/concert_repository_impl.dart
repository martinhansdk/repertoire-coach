import '../../core/services/error_reporter.dart';
import '../../core/services/supabase_service.dart';
import '../../domain/entities/concert.dart';
import '../../domain/repositories/concert_repository.dart';
import '../datasources/local/local_concert_data_source.dart';
import '../datasources/remote/remote_concert_data_source.dart';
import '../models/concert_model.dart';

/// Concert repository implementation with offline-first sync
///
/// Uses both local (Drift/SQLite) and remote (Supabase) data sources.
/// - Reads always from local DB (fast, works offline)
/// - Writes to both local AND remote when authenticated
/// - Background sync ensures data consistency
class ConcertRepositoryImpl implements ConcertRepository {
  final LocalConcertDataSource _localDataSource;
  final RemoteConcertDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;

  ConcertRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
  );

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

  @override
  Future<void> createConcert(Concert concert) async {
    final concertModel = ConcertModel.fromEntity(concert);

    // Save to local database
    await _localDataSource.insertConcert(concertModel);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.createConcert(concertModel);
        await _localDataSource.markAsSynced(concert.id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'concert_repository');
      }
    }
  }

  @override
  Future<bool> updateConcert(Concert concert) async {
    final concertModel = ConcertModel.fromEntity(concert);

    // Update in local database
    final result = await _localDataSource.updateConcert(concertModel);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.updateConcert(concertModel);
        await _localDataSource.markAsSynced(concert.id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'concert_repository');
      }
    }

    return result;
  }

  @override
  Future<void> deleteConcert(String concertId) async {
    // Delete from local database
    await _localDataSource.deleteConcert(concertId);

    // Sync to remote if authenticated
    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.deleteConcert(concertId);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'concert_repository');
      }
    }
  }
}
