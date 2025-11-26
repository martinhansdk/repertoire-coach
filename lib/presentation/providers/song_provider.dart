import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_song_data_source.dart';
import '../../data/repositories/song_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';
import 'concert_provider.dart';

/// Provider for the local song data source
///
/// Wraps database operations for song management.
final localSongDataSourceProvider = Provider<LocalSongDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalSongDataSource(database);
});

/// Provider for the song repository
///
/// This provides a single instance of the repository throughout the app.
/// Currently uses local Drift database. Future versions will add Supabase sync.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  final localDataSource = ref.watch(localSongDataSourceProvider);
  return SongRepositoryImpl(localDataSource);
});

/// Provider for songs filtered by a specific concert
///
/// Usage: ref.watch(songsByConcertProvider('concert-id'))
final songsByConcertProvider =
    FutureProvider.family<List<Song>, String>((ref, concertId) async {
  try {
    final repository = ref.watch(songRepositoryProvider);
    return await repository.getSongsByConcert(concertId);
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
});

/// Provider for a single song by ID
///
/// Usage: ref.watch(songByIdProvider('song-id'))
final songByIdProvider =
    FutureProvider.family<Song?, String>((ref, songId) async {
  final repository = ref.watch(songRepositoryProvider);
  return await repository.getSongById(songId);
});
