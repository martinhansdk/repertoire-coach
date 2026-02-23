import '../../core/services/error_reporter.dart';
import '../../core/services/supabase_service.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';
import '../datasources/local/local_song_data_source.dart';
import '../datasources/remote/remote_song_data_source.dart';
import '../models/song_model.dart';

class SongRepositoryImpl implements SongRepository {
  final LocalSongDataSource _localDataSource;
  final RemoteSongDataSource? _remoteDataSource;
  final SupabaseService _supabaseService;

  SongRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseService,
  );

  @override
  Future<List<Song>> getSongsByConcert(String concertId) async {
    final songModels = await _localDataSource.getSongsByConcert(concertId);
    return songModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Song?> getSongById(String songId) async {
    final songModel = await _localDataSource.getSongById(songId);
    return songModel?.toEntity();
  }

  @override
  Future<void> createSong(Song song) async {
    final songModel = SongModel.fromEntity(song);
    await _localDataSource.insertSong(songModel);

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.createSong(songModel);
        await _localDataSource.markAsSynced(song.id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'song_repository');
      }
    }
  }

  @override
  Future<bool> updateSong(Song song) async {
    final songModel = SongModel.fromEntity(song);
    final result = await _localDataSource.updateSong(songModel);

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.updateSong(songModel);
        await _localDataSource.markAsSynced(song.id);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'song_repository');
      }
    }

    return result;
  }

  @override
  Future<void> deleteSong(String songId) async {
    await _localDataSource.deleteSong(songId);

    if (_supabaseService.isAuthenticated && _remoteDataSource != null) {
      try {
        await _remoteDataSource.deleteSong(songId);
      } catch (e, st) {
        ErrorReporter.report(e, stackTrace: st, screen: 'song_repository');
      }
    }
  }
}
