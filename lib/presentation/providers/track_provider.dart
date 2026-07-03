import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_storage_service.dart';
import '../../data/datasources/local/local_track_data_source.dart';
import '../../data/datasources/remote/remote_track_data_source.dart';
import '../../data/repositories/track_repository_impl.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';
import 'auth_provider.dart';
import 'concert_provider.dart';

/// Provider for the local track data source
///
/// Wraps database operations for track management.
final localTrackDataSourceProvider = Provider<LocalTrackDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalTrackDataSource(database);
});

/// Provider for the remote track data source
///
/// Wraps Supabase operations for track management.
/// Only used when user is authenticated.
final remoteTrackDataSourceProvider = Provider<RemoteTrackDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (!supabaseService.isAuthenticated) {
    return null;
  }
  return RemoteTrackDataSource(supabaseService.client);
});

/// Provider for the audio storage service
///
/// Handles uploading and managing audio files in R2 storage.
final audioStorageServiceProvider = Provider<AudioStorageService>((ref) {
  final signerClient = ref.watch(r2SignerClientProvider);
  return AudioStorageService(signerClient);
});

/// Provider for the track repository
///
/// Offline-first: reads and writes go to the local (Drift/SQLite) database;
/// the sync service owns all remote (Supabase) I/O.
final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  final localDataSource = ref.watch(localTrackDataSourceProvider);
  return TrackRepositoryImpl(localDataSource);
});

/// Provider for tracks filtered by a specific song
///
/// Returns tracks sorted alphabetically by name.
/// Usage: ref.watch(tracksBySongProvider('song-id'))
final tracksBySongProvider =
    FutureProvider.family<List<Track>, String>((ref, songId) async {
  try {
    final repository = ref.watch(trackRepositoryProvider);
    final tracks = await repository.getTracksBySong(songId);
    // Sort alphabetically by name
    tracks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return tracks;
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
