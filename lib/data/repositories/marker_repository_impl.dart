import '../../core/services/error_reporter.dart';
import '../../core/errors/marker_invariant_exception.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
import '../../domain/repositories/marker_repository.dart';
import '../datasources/local/local_marker_data_source.dart';
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

  MarkerRepositoryImpl(
    this._localDataSource,
  );

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

  }

  @override
  Future<bool> updateMarkerSet(MarkerSet markerSet) async {
    final existing = await _localDataSource.getMarkerSetById(markerSet.id);
    final markerSetModel = MarkerSetModel(
      id: markerSet.id,
      trackId: markerSet.trackId,
      name: markerSet.name,
      isShared: markerSet.isShared,
      isTimeSynced: markerSet.isTimeSynced,
      createdByUserId: markerSet.createdByUserId,
      createdAt: markerSet.createdAt,
      updatedAt: markerSet.updatedAt,
      deleted: existing?.deleted ?? false,
      markersJson: existing?.markersJson ?? '[]',
    );

    // Update local database first
    final success = await _localDataSource.updateMarkerSet(markerSetModel);


    return success;
  }

  @override
  Future<void> deleteMarkerSet(String markerSetId) async {
    // Delete from local database first
    await _localDataSource.deleteMarkerSet(markerSetId);

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

    // Save marker payload to local marker_set first (offline-first)
    await _localDataSource.insertMarker(markerModel);
  }

  @override
  Future<bool> updateMarker(Marker marker) async {
    final markerModel = MarkerModel.fromEntity(marker);

    // Update marker payload in the local marker_set (offline-first);
    // the sync service pushes the change to remote.
    return _localDataSource.updateMarker(markerModel);
  }

  @override
  Future<void> deleteMarker(String markerId) async {
    final marker = await _localDataSource.getMarkerById(markerId);
    if (marker == null) {
      return;
    }
    await _localDataSource.deleteMarker(markerId);
  }

  @override
  Future<void> deleteMarkersByMarkerSet(String markerSetId) async {
    await _localDataSource.deleteMarkersByMarkerSet(markerSetId);
  }

  @override
  Future<void> replaceMarkersByMarkerSet(
    String markerSetId,
    List<Marker> markers,
  ) async {
    _assertMonotonicMarkers(markers);
    final models = markers.map(MarkerModel.fromEntity).toList(growable: false);
    await _localDataSource.replaceMarkersByMarkerSet(markerSetId, models);
  }



  void _assertMonotonicMarkers(List<Marker> markers) {
    int? previousPosition;
    for (var i = 0; i < markers.length; i++) {
      final positionMs = markers[i].positionMs;
      if (positionMs == null) {
        continue;
      }
      if (previousPosition != null && positionMs < previousPosition) {
        throw MarkerInvariantException(
          'Markers must be monotonic by order. Index $i has $positionMs, '
          'previous synced marker had $previousPosition.',
        );
      }
      previousPosition = positionMs;
    }
  }
}
