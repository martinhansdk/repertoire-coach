import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';
import '../datasources/local/local_track_data_source.dart';
import '../models/track_model.dart';

class TrackRepositoryImpl implements TrackRepository {
  final LocalTrackDataSource _localDataSource;

  TrackRepositoryImpl(
    this._localDataSource,
  );

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
    final result = await _localDataSource.updateTrack(trackModel);


    return result;
  }

  @override
  Future<void> deleteTrack(String trackId) async {
    await _localDataSource.deleteTrack(trackId);

  }
}
