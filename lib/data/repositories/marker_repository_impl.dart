import '../../core/services/supabase_service.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
import '../../domain/repositories/marker_repository.dart';
import '../datasources/local/local_marker_data_source.dart';
import '../datasources/remote/remote_marker_data_source.dart';
import '../models/marker_model.dart';
import '../models/marker_set_model.dart';

/// Marker repository implementation with offline-first sync
///
/// Provides offline-first data persistence with automatic cloud sync.
/// - Reads always come from local database (fast)
/// - Writes go to both local and cloud (when authenticated)
/// - Background sync keeps data updated
class MarkerRepositoryImpl implements MarkerRepository {
  final LocalMarkerDataSource _localDataSource;
  final RemoteMarkerDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;

  MarkerRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
  );

  /// Check if user is authenticated and remote operations are available
  bool get _canSyncToRemote =>
      _supabaseService.isAuthenticated && _remoteDataSource != null;

  // ==================== MarkerSet Operations ====================

  @override
  Future<List<MarkerSet>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) async {
    // Always read from local database for fast access
    final markerSetModels = await _localDataSource.getMarkerSetsByTrack(
      trackId,
      userId: userId,
    );

    // Convert to domain entities
    return markerSetModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<MarkerSet?> getMarkerSetById(String markerSetId) async {
    final markerSetModel =
        await _localDataSource.getMarkerSetById(markerSetId);

    return markerSetModel?.toEntity();
  }

  @override
  Future<void> createMarkerSet(MarkerSet markerSet) async {
    final markerSetModel = MarkerSetModel.fromEntity(markerSet);

    // Always save to local database first (offline-first)
    await _localDataSource.insertMarkerSet(markerSetModel);

    // Sync to Supabase if authenticated
    if (_canSyncToRemote) {
      try {
        await _remoteDataSource!.createMarkerSet(markerSetModel);
      } catch (e) {
        // Log error but don't fail - data is already saved locally
        // TODO: Use proper logging framework
// ignore: avoid_print
print('Failed to sync marker set to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }
  }

  @override
  Future<bool> updateMarkerSet(MarkerSet markerSet) async {
    final markerSetModel = MarkerSetModel.fromEntity(markerSet);

    // Update local database first
    final success = await _localDataSource.updateMarkerSet(markerSetModel);

    // Sync to Supabase if authenticated
    if (success && _canSyncToRemote) {
      try {
        await _remoteDataSource!.updateMarkerSet(markerSetModel);
      } catch (e) {
        // Log error but don't fail - data is already saved locally
        // ignore: avoid_print
print('Failed to sync marker set update to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }

    return success;
  }

  @override
  Future<void> deleteMarkerSet(String markerSetId) async {
    // Delete from local database first
    await _localDataSource.deleteMarkerSet(markerSetId);

    // Sync deletion to Supabase if authenticated
    if (_canSyncToRemote) {
      try {
        await _remoteDataSource!.deleteMarkerSet(markerSetId);
      } catch (e) {
        // Log error but don't fail - data is already deleted locally
        // ignore: avoid_print
print('Failed to sync marker set deletion to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }
  }

  // ==================== Marker Operations ====================

  @override
  Future<List<Marker>> getMarkersByMarkerSet(String markerSetId) async {
    // Always read from local database for fast access
    final markerModels =
        await _localDataSource.getMarkersByMarkerSet(markerSetId);

    // Convert to domain entities
    return markerModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Marker?> getMarkerById(String markerId) async {
    final markerModel = await _localDataSource.getMarkerById(markerId);

    return markerModel?.toEntity();
  }

  @override
  Future<void> createMarker(Marker marker) async {
    final markerModel = MarkerModel.fromEntity(marker);

    // Always save to local database first (offline-first)
    await _localDataSource.insertMarker(markerModel);

    // Sync to Supabase if authenticated
    if (_canSyncToRemote) {
      try {
        await _remoteDataSource!.createMarker(markerModel);
      } catch (e) {
        // Log error but don't fail - data is already saved locally
        // ignore: avoid_print
print('Failed to sync marker to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }
  }

  @override
  Future<bool> updateMarker(Marker marker) async {
    final markerModel = MarkerModel.fromEntity(marker);

    // Update local database first
    final success = await _localDataSource.updateMarker(markerModel);

    // Sync to Supabase if authenticated
    if (success && _canSyncToRemote) {
      try {
        await _remoteDataSource!.updateMarker(markerModel);
      } catch (e) {
        // Log error but don't fail - data is already saved locally
        // ignore: avoid_print
print('Failed to sync marker update to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }

    return success;
  }

  @override
  Future<void> deleteMarker(String markerId) async {
    // Delete from local database first
    await _localDataSource.deleteMarker(markerId);

    // Sync deletion to Supabase if authenticated
    if (_canSyncToRemote) {
      try {
        await _remoteDataSource!.deleteMarker(markerId);
      } catch (e) {
        // Log error but don't fail - data is already deleted locally
        // ignore: avoid_print
print('Failed to sync marker deletion to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }
  }

  @override
  Future<void> deleteMarkersByMarkerSet(String markerSetId) async {
    // Delete from local database first
    await _localDataSource.deleteMarkersByMarkerSet(markerSetId);

    // Sync deletion to Supabase if authenticated
    if (_canSyncToRemote) {
      try {
        await _remoteDataSource!.deleteMarkersBySetId(markerSetId);
      } catch (e) {
        // Log error but don't fail - data is already deleted locally
        // ignore: avoid_print
print('Failed to sync markers deletion to Supabase: $e');
        // TODO: Add to sync queue for retry
      }
    }
  }
}
