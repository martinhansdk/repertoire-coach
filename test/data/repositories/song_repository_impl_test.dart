import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/data/models/song_model.dart';
import 'package:repertoire_coach/data/repositories/song_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/song_repository.dart';

void main() {
  group('SongRepositoryImpl', () {
    late db.AppDatabase database;
    late LocalSongDataSource dataSource;
    late SongRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalSongDataSource(database);
      repository = SongRepositoryImpl(dataSource);

      // Seed test data
      await _seedTestData(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('should return all songs for a specific concert', () async {
      // Arrange
      const concertId = 'concert1';

      // Act
      final songs = await repository.getSongsByConcert(concertId);

      // Assert
      expect(songs, isNotEmpty);
      expect(songs.length, 3); // concert1 has 3 songs

      // Verify all songs belong to the concert
      for (final song in songs) {
        expect(song.concertId, concertId);
      }

      // Verify songs are sorted chronologically (oldest first)
      for (int i = 0; i < songs.length - 1; i++) {
        expect(
          songs[i].createdAt.isBefore(songs[i + 1].createdAt) ||
              songs[i].createdAt.isAtSameMomentAs(songs[i + 1].createdAt),
          isTrue,
          reason: 'Songs should be sorted chronologically (oldest first)',
        );
      }
    });

    test('should return empty list for concert with no songs', () async {
      // Arrange
      const concertId = 'concert-empty';

      // Act
      final songs = await repository.getSongsByConcert(concertId);

      // Assert
      expect(songs, isEmpty);
    });

    test('should return song by id', () async {
      // Arrange
      const songId = 'song1';

      // Act
      final song = await repository.getSongById(songId);

      // Assert
      expect(song, isNotNull);
      expect(song!.id, songId);
      expect(song.title, 'Ave Verum Corpus');
    });

    test('should return null for non-existent song id', () async {
      // Arrange
      const songId = 'non-existent';

      // Act
      final song = await repository.getSongById(songId);

      // Assert
      expect(song, isNull);
    });

    test('should create a new song', () async {
      // Arrange
      final now = DateTime.now();
      final newSong = SongModel(
        id: 'new-song',
        concertId: 'concert1',
        title: 'New Song Title',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      await repository.createSong(newSong);

      // Assert - verify it was created
      final retrieved = await repository.getSongById('new-song');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'new-song');
      expect(retrieved.title, 'New Song Title');
      expect(retrieved.concertId, 'concert1');
    });

    test('should update an existing song', () async {
      // Arrange
      final existingSong = await repository.getSongById('song1');
      expect(existingSong, isNotNull);

      final updatedSong = SongModel(
        id: 'song1',
        concertId: existingSong!.concertId,
        title: 'Updated Song Title',
        createdAt: existingSong.createdAt,
        updatedAt: DateTime.now(),
      );

      // Act
      final success = await repository.updateSong(updatedSong);

      // Assert
      expect(success, isTrue);

      // Verify the song was updated
      final retrieved = await repository.getSongById('song1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Updated Song Title');
      expect(retrieved.concertId, existingSong.concertId);
    });

    test('should return false when updating non-existent song', () async {
      // Arrange
      final now = DateTime.now();
      final nonExistentSong = SongModel(
        id: 'non-existent',
        concertId: 'concert1',
        title: 'Should Not Update',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final success = await repository.updateSong(nonExistentSong);

      // Assert
      expect(success, isFalse);
    });

    test('should delete a song (soft delete)', () async {
      // Arrange
      const songId = 'song1';

      // Verify song exists before deletion
      final beforeDelete = await repository.getSongById(songId);
      expect(beforeDelete, isNotNull);

      // Act
      await repository.deleteSong(songId);

      // Assert - song should no longer be retrievable
      final afterDelete = await repository.getSongById(songId);
      expect(afterDelete, isNull);

      // Verify it's removed from the songs list
      final allSongs = await repository.getSongsByConcert('concert1');
      expect(allSongs.every((s) => s.id != songId), isTrue);
    });

    test('should handle deleting non-existent song gracefully', () async {
      // Act & Assert - should not throw
      await repository.deleteSong('non-existent-id');
    });

    test('should maintain song order after updates', () async {
      // Arrange
      const concertId = 'concert1';
      final songsBeforeUpdate = await repository.getSongsByConcert(concertId);

      // Update the second song
      final songToUpdate = songsBeforeUpdate[1];
      final updatedSong = SongModel(
        id: songToUpdate.id,
        concertId: songToUpdate.concertId,
        title: 'Updated Title',
        createdAt: songToUpdate.createdAt,
        updatedAt: DateTime.now(),
      );

      // Act
      await repository.updateSong(updatedSong);

      // Assert - order should remain the same (based on createdAt)
      final songsAfterUpdate = await repository.getSongsByConcert(concertId);
      expect(songsAfterUpdate.length, songsBeforeUpdate.length);

      for (int i = 0; i < songsAfterUpdate.length; i++) {
        expect(songsAfterUpdate[i].id, songsBeforeUpdate[i].id,
            reason: 'Song order should remain unchanged after update');
      }
    });

    test('should handle multiple songs with same creation time', () async {
      // Arrange
      final now = DateTime.now();
      final song1 = SongModel(
        id: 'same-time-1',
        concertId: 'concert-test',
        title: 'Song A',
        createdAt: now,
        updatedAt: now,
      );
      final song2 = SongModel(
        id: 'same-time-2',
        concertId: 'concert-test',
        title: 'Song B',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      await repository.createSong(song1);
      await repository.createSong(song2);

      // Assert
      final songs = await repository.getSongsByConcert('concert-test');
      expect(songs.length, 2);
      // Both songs should be retrievable
      expect(songs.any((s) => s.id == 'same-time-1'), isTrue);
      expect(songs.any((s) => s.id == 'same-time-2'), isTrue);
    });
  });
}

/// Seed test data into the database
Future<void> _seedTestData(LocalSongDataSource dataSource) async {
  final testSongs = [
    // Concert 1 songs
    SongModel(
      id: 'song1',
      concertId: 'concert1',
      title: 'Ave Verum Corpus',
      createdAt: DateTime(2024, 12, 1, 10, 0),
      updatedAt: DateTime(2024, 12, 1, 10, 0),
    ),
    SongModel(
      id: 'song2',
      concertId: 'concert1',
      title: 'Lux Aurumque',
      createdAt: DateTime(2024, 12, 1, 11, 0),
      updatedAt: DateTime(2024, 12, 1, 11, 0),
    ),
    SongModel(
      id: 'song3',
      concertId: 'concert1',
      title: 'The Seal Lullaby',
      createdAt: DateTime(2024, 12, 1, 12, 0),
      updatedAt: DateTime(2024, 12, 1, 12, 0),
    ),
    // Concert 2 songs
    SongModel(
      id: 'song4',
      concertId: 'concert2',
      title: 'O Holy Night',
      createdAt: DateTime(2024, 12, 2, 10, 0),
      updatedAt: DateTime(2024, 12, 2, 10, 0),
    ),
    SongModel(
      id: 'song5',
      concertId: 'concert2',
      title: 'Silent Night',
      createdAt: DateTime(2024, 12, 2, 11, 0),
      updatedAt: DateTime(2024, 12, 2, 11, 0),
    ),
  ];

  for (final song in testSongs) {
    await dataSource.upsertSong(song, markForSync: false);
  }
}
