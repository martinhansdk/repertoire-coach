import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';
import '../datasources/local/local_track_data_source.dart';
import '../models/track_model.dart';

/// Implementation of TrackRepository using local Drift database
///
/// This is the production implementation that uses SQLite via Drift.
/// All data is stored locally. Future versions will add Supabase sync.
class TrackRepositoryImpl implements TrackRepository {
  final LocalTrackDataSource _localDataSource;

  TrackRepositoryImpl(this._localDataSource);

  @override
  Future<List<Track>> getTracksBySong(String songId) async {
    final trackModels = await _localDataSource.getTracksBySong(songId);
    return trackModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Track?> getTrackById(String trackId) async {
    final trackModel = await _localDataSource.getTrackById(trackId);
    return trackModel?.toEntity();
  }

  @override
  Future<void> createTrack(Track track) async {
    final trackModel = TrackModel.fromEntity(track);
    await _localDataSource.insertTrack(trackModel);
  }

  @override
  Future<bool> updateTrack(Track track) async {
    final trackModel = TrackModel.fromEntity(track);
    return await _localDataSource.updateTrack(trackModel);
  }

  @override
  Future<void> deleteTrack(String trackId) async {
    await _localDataSource.deleteTrack(trackId);
  }
}
