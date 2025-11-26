import '../../domain/entities/song.dart';
import '../../domain/repositories/song_repository.dart';
import '../datasources/local/local_song_data_source.dart';
import '../models/song_model.dart';

/// Song repository implementation using local Drift database
///
/// Provides offline-first data persistence with SQLite.
/// All data is stored locally and works without internet connection.
/// Future versions will add cloud sync with Supabase.
class SongRepositoryImpl implements SongRepository {
  final LocalSongDataSource _localDataSource;

  SongRepositoryImpl(this._localDataSource);

  @override
  Future<List<Song>> getSongsByConcert(String concertId) async {
    // Get all songs for the concert from local database
    final songModels = await _localDataSource.getSongsByConcert(concertId);

    // Convert to domain entities
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
    return await _localDataSource.updateSong(songModel);
  }

  @override
  Future<void> deleteSong(String songId) async {
    await _localDataSource.deleteSong(songId);
  }
}
