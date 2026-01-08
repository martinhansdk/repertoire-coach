import '../../core/services/supabase_service.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/track_repository.dart';
import '../datasources/local/local_track_data_source.dart';
import '../datasources/remote/remote_track_data_source.dart';
import '../models/track_model.dart';

class TrackRepositoryImpl implements TrackRepository {
  final LocalTrackDataSource _localDataSource;
  final RemoteTrackDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;

  TrackRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
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

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.createTrack(trackModel);
        await _localDataSource.markAsSynced(track.id);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to sync track to remote: $e');
      }
    }
  }

  @override
  Future<bool> updateTrack(Track track) async {
    final trackModel = TrackModel.fromEntity(track);
    final result = await _localDataSource.updateTrack(trackModel);

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.updateTrack(trackModel);
        await _localDataSource.markAsSynced(track.id);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to sync track update to remote: $e');
      }
    }

    return result;
  }

  @override
  Future<void> deleteTrack(String trackId) async {
    await _localDataSource.deleteTrack(trackId);

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.deleteTrack(trackId);
      } catch (e) {
        // ignore: avoid_print
        print('Failed to sync track deletion to remote: $e');
      }
    }
  }
}
