import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_song_data_source.dart';
import '../../data/datasources/remote/remote_song_data_source.dart';
import '../../data/repositories/song_repository_impl.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';
import 'concert_provider.dart';
import 'auth_provider.dart'; // For supabaseServiceProvider

/// Provider for the local song data source
///
/// Wraps database operations for song management.
final localSongDataSourceProvider = Provider<LocalSongDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalSongDataSource(database);
});

/// Provider for the remote song data source
///
/// Wraps Supabase operations for song management.
/// Only used when user is authenticated.
final remoteSongDataSourceProvider = Provider<RemoteSongDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (!supabaseService.isAuthenticated) {
    return null;
  }
  return RemoteSongDataSource(supabaseService.client);
});

/// Provider for the song repository
///
/// Uses both local (Drift/SQLite) and remote (Supabase) data sources.
/// Implements offline-first pattern: reads from local, writes to both.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  final localDataSource = ref.watch(localSongDataSourceProvider);
  final remoteDataSource = ref.watch(remoteSongDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SongRepositoryImpl(
    localDataSource,
    remoteDataSource,
    supabaseService,
  );
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
