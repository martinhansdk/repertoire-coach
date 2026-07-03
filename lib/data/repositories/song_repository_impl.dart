import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';
import '../datasources/local/local_song_data_source.dart';
import '../models/song_model.dart';

class SongRepositoryImpl implements SongRepository {
  final LocalSongDataSource _localDataSource;

  SongRepositoryImpl(
    this._localDataSource,
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

  }

  @override
  Future<bool> updateSong(Song song) async {
    final songModel = SongModel.fromEntity(song);
    final result = await _localDataSource.updateSong(songModel);


    return result;
  }

  @override
  Future<void> deleteSong(String songId) async {
    await _localDataSource.deleteSong(songId);

  }
}
