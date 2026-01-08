import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/datasources/local/local_concert_data_source.dart';
import '../../data/datasources/remote/remote_concert_data_source.dart';
import '../../data/repositories/concert_repository_impl.dart';
import '../../domain/entities/concert.dart';
import '../../domain/repositories/concert_repository.dart';
import 'auth_provider.dart'; // For supabaseServiceProvider

/// Provider for the Drift database instance
///
/// This is a singleton that persists for the lifetime of the app.
/// The database connection is lazily initialized on first access.
final databaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

/// Provider for the local concert data source
///
/// Wraps database operations for concert management.
final localConcertDataSourceProvider = Provider<LocalConcertDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalConcertDataSource(database);
});

/// Provider for the remote concert data source
///
/// Wraps Supabase operations for concert management.
/// Only used when user is authenticated.
final remoteConcertDataSourceProvider = Provider<RemoteConcertDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (!supabaseService.isAuthenticated) {
    return null;
  }
  return RemoteConcertDataSource(supabaseService.client);
});

/// Provider for the concert repository
///
/// Uses both local (Drift/SQLite) and remote (Supabase) data sources.
/// Implements offline-first pattern: reads from local, writes to both.
final concertRepositoryProvider = Provider<ConcertRepository>((ref) {
  final localDataSource = ref.watch(localConcertDataSourceProvider);
  final remoteDataSource = ref.watch(remoteConcertDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ConcertRepositoryImpl(
    localDataSource,
    remoteDataSource,
    supabaseService,
  );
});

/// Provider for the list of concerts
///
/// Fetches all concerts from the repository and automatically sorts them
/// by date (upcoming first, then past).
final concertsProvider = FutureProvider<List<Concert>>((ref) async {
  try {
    final repository = ref.watch(concertRepositoryProvider);
    return await repository.getConcerts();
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
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
