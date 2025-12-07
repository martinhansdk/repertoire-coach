import '../../domain/entities/marker.dart';
import '../../domain/entities/marker_set.dart';
import '../../domain/repositories/marker_repository.dart';
import '../datasources/local/local_marker_data_source.dart';
import '../models/marker_model.dart';
import '../models/marker_set_model.dart';

/// Marker repository implementation using local Drift database
///
/// Provides offline-first data persistence with SQLite.
/// All data is stored locally and works without internet connection.
/// Future versions will add cloud sync with Supabase.
class MarkerRepositoryImpl implements MarkerRepository {
  final LocalMarkerDataSource _localDataSource;

  MarkerRepositoryImpl(this._localDataSource);

  // ==================== MarkerSet Operations ====================

  @override
  Future<List<MarkerSet>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) async {
    // Get all marker sets for the track from local database
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
    await _localDataSource.insertMarkerSet(markerSetModel);
  }

  @override
  Future<bool> updateMarkerSet(MarkerSet markerSet) async {
    final markerSetModel = MarkerSetModel.fromEntity(markerSet);
    return await _localDataSource.updateMarkerSet(markerSetModel);
  }

  @override
  Future<void> deleteMarkerSet(String markerSetId) async {
    await _localDataSource.deleteMarkerSet(markerSetId);
  }

  // ==================== Marker Operations ====================

  @override
  Future<List<Marker>> getMarkersByMarkerSet(String markerSetId) async {
    // Get all markers for the marker set from local database
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
    await _localDataSource.insertMarker(markerModel);
  }

  @override
  Future<bool> updateMarker(Marker marker) async {
    final markerModel = MarkerModel.fromEntity(marker);
    return await _localDataSource.updateMarker(markerModel);
  }

  @override
  Future<void> deleteMarker(String markerId) async {
    await _localDataSource.deleteMarker(markerId);
  }
}
