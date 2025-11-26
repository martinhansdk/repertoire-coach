import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_track_data_source.dart';
import '../../data/repositories/track_repository_impl.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';
import 'concert_provider.dart';

/// Provider for the local track data source
///
/// Wraps database operations for track management.
final localTrackDataSourceProvider = Provider<LocalTrackDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalTrackDataSource(database);
});

/// Provider for the track repository
///
/// This provides a single instance of the repository throughout the app.
/// Currently uses local Drift database. Future versions will add Supabase sync.
final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  final localDataSource = ref.watch(localTrackDataSourceProvider);
  return TrackRepositoryImpl(localDataSource);
});

/// Provider for tracks filtered by a specific song
///
/// Usage: ref.watch(tracksBySongProvider('song-id'))
final tracksBySongProvider =
    FutureProvider.family<List<Track>, String>((ref, songId) async {
  try {
    final repository = ref.watch(trackRepositoryProvider);
    return await repository.getTracksBySong(songId);
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
});

/// Provider for a single track by ID
///
/// Usage: ref.watch(trackByIdProvider('track-id'))
final trackByIdProvider =
    FutureProvider.family<Track?, String>((ref, trackId) async {
  final repository = ref.watch(trackRepositoryProvider);
  return await repository.getTrackById(trackId);
});
