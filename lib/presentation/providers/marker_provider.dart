import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_marker_data_source.dart';
import '../../data/datasources/remote/remote_marker_data_source.dart';
import '../../data/repositories/marker_repository_impl.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
import '../../domain/repositories/marker_repository.dart';
import 'auth_provider.dart';
import 'concert_provider.dart';

/// Provider for the local marker data source
///
/// Wraps database operations for marker and marker set management.
final localMarkerDataSourceProvider = Provider<LocalMarkerDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalMarkerDataSource(database);
});

/// Provider for the remote marker data source
///
/// Provides Supabase-backed storage for markers and marker sets.
/// Returns null if not authenticated.
final remoteMarkerDataSourceProvider = Provider<RemoteMarkerDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (!supabaseService.isAuthenticated) {
    return null;
  }
  return RemoteMarkerDataSource(supabaseService.client);
});

/// Provider for the marker repository
///
/// Provides offline-first data persistence.
/// - Writes go to the local database (marked unsynced); the sync service owns
///   all remote Supabase I/O
/// - Reads always come from local database for fast access
final markerRepositoryProvider = Provider<MarkerRepository>((ref) {
  final localDataSource = ref.watch(localMarkerDataSourceProvider);
  return MarkerRepositoryImpl(localDataSource);
});

/// Provider for marker sets filtered by a specific track
///
/// Usage: ref.watch(markerSetsByTrackProvider(('track-id', 'user-id')))
/// userId can be null to get all marker sets
final markerSetsByTrackProvider =
    FutureProvider.family<List<MarkerSet>, (String, String?)>(
        (ref, params) async {
  final (trackId, userId) = params;
  try {
    final repository = ref.watch(markerRepositoryProvider);
    return await repository.getMarkerSetsByTrack(trackId, userId: userId);
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
});

/// Provider for a single marker set by ID
///
/// Usage: ref.watch(markerSetByIdProvider('marker-set-id'))
final markerSetByIdProvider =
    FutureProvider.family<MarkerSet?, String>((ref, markerSetId) async {
  final repository = ref.watch(markerRepositoryProvider);
  return await repository.getMarkerSetById(markerSetId);
});

/// Provider for markers filtered by a specific marker set
///
/// Usage: ref.watch(markersByMarkerSetProvider('marker-set-id'))
final markersByMarkerSetProvider =
    FutureProvider.family<List<Marker>, String>((ref, markerSetId) async {
  try {
    final repository = ref.watch(markerRepositoryProvider);
    return await repository.getMarkersByMarkerSet(markerSetId);
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
});

/// Provider for a single marker by ID
///
/// Usage: ref.watch(markerByIdProvider('marker-id'))
final markerByIdProvider =
    FutureProvider.family<Marker?, String>((ref, markerId) async {
  final repository = ref.watch(markerRepositoryProvider);
  return await repository.getMarkerById(markerId);
});
