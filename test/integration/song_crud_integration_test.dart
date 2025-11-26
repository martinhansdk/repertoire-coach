import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/data/repositories/song_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/repositories/song_repository.dart';

/// Integration test for the complete song CRUD workflow
///
/// Tests the full flow from domain layer through data layer to database.
void main() {
  group('Song CRUD Integration Test', () {
    late db.AppDatabase database;
    late LocalSongDataSource dataSource;
    late SongRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalSongDataSource(database);
      repository = SongRepositoryImpl(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('complete song lifecycle: create, read, update, delete', () async {
      // Step 1: Create a song
      final now = DateTime.now();
      final newSong = Song(
        id: 'integration-test-song',
        concertId: 'test-concert',
        title: 'Test Song',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createSong(newSong);

      // Step 2: Read the song back
      final retrievedSong = await repository.getSongById('integration-test-song');
      expect(retrievedSong, isNotNull);
      expect(retrievedSong!.id, 'integration-test-song');
      expect(retrievedSong.title, 'Test Song');
      expect(retrievedSong.concertId, 'test-concert');

      // Step 3: Update the song
      final updatedSong = Song(
        id: retrievedSong.id,
        concertId: retrievedSong.concertId,
        title: 'Updated Test Song',
        createdAt: retrievedSong.createdAt,
        updatedAt: DateTime.now(),
      );

      final updateSuccess = await repository.updateSong(updatedSong);
      expect(updateSuccess, isTrue);

      // Verify the update
      final afterUpdate = await repository.getSongById('integration-test-song');
      expect(afterUpdate, isNotNull);
      expect(afterUpdate!.title, 'Updated Test Song');

      // Step 4: Delete the song
      await repository.deleteSong('integration-test-song');

      // Verify deletion
      final afterDelete = await repository.getSongById('integration-test-song');
      expect(afterDelete, isNull);
    });

    test('multiple songs in a concert: create, list, and order', () async {
      const concertId = 'multi-song-concert';
      final now = DateTime.now();

      // Create multiple songs with different creation times
      final songs = [
        Song(
          id: 'song-1',
          concertId: concertId,
          title: 'First Song',
          createdAt: now,
          updatedAt: now,
        ),
        Song(
          id: 'song-2',
          concertId: concertId,
          title: 'Second Song',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        Song(
          id: 'song-3',
          concertId: concertId,
          title: 'Third Song',
          createdAt: now.add(const Duration(seconds: 2)),
          updatedAt: now.add(const Duration(seconds: 2)),
        ),
      ];

      // Create all songs
      for (final song in songs) {
        await repository.createSong(song);
      }

      // Retrieve all songs for the concert
      final retrievedSongs = await repository.getSongsByConcert(concertId);

      // Verify count
      expect(retrievedSongs.length, 3);

      // Verify chronological order (oldest first)
      expect(retrievedSongs[0].id, 'song-1');
      expect(retrievedSongs[1].id, 'song-2');
      expect(retrievedSongs[2].id, 'song-3');

      // Verify titles
      expect(retrievedSongs[0].title, 'First Song');
      expect(retrievedSongs[1].title, 'Second Song');
      expect(retrievedSongs[2].title, 'Third Song');
    });

    test('songs are isolated by concert', () async {
      final now = DateTime.now();

      // Create songs for different concerts
      await repository.createSong(Song(
        id: 'concert1-song1',
        concertId: 'concert-1',
        title: 'Concert 1 - Song 1',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.createSong(Song(
        id: 'concert1-song2',
        concertId: 'concert-1',
        title: 'Concert 1 - Song 2',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.createSong(Song(
        id: 'concert2-song1',
        concertId: 'concert-2',
        title: 'Concert 2 - Song 1',
        createdAt: now,
        updatedAt: now,
      ));

      // Retrieve songs for concert 1
      final concert1Songs = await repository.getSongsByConcert('concert-1');
      expect(concert1Songs.length, 2);
      expect(concert1Songs.every((s) => s.concertId == 'concert-1'), isTrue);

      // Retrieve songs for concert 2
      final concert2Songs = await repository.getSongsByConcert('concert-2');
      expect(concert2Songs.length, 1);
      expect(concert2Songs.every((s) => s.concertId == 'concert-2'), isTrue);
    });

    test('update preserves creation time and concert association', () async {
      final createdAt = DateTime(2024, 1, 1, 10, 0, 0);
      final originalSong = Song(
        id: 'preserve-test',
        concertId: 'original-concert',
        title: 'Original Title',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      // Create the song
      await repository.createSong(originalSong);

      // Update only the title
      final updatedSong = Song(
        id: originalSong.id,
        concertId: originalSong.concertId,
        title: 'New Title',
        createdAt: originalSong.createdAt,
        updatedAt: DateTime.now(),
      );

      await repository.updateSong(updatedSong);

      // Verify creation time and concert are preserved
      final retrieved = await repository.getSongById('preserve-test');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'New Title');
      expect(retrieved.concertId, 'original-concert');
      expect(retrieved.createdAt, createdAt);
    });

    test('deleting song does not affect other songs', () async {
      final now = DateTime.now();
      const concertId = 'delete-isolation-test';

      // Create multiple songs
      await repository.createSong(Song(
        id: 'keep-1',
        concertId: concertId,
        title: 'Keep Song 1',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.createSong(Song(
        id: 'delete-this',
        concertId: concertId,
        title: 'Delete This Song',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.createSong(Song(
        id: 'keep-2',
        concertId: concertId,
        title: 'Keep Song 2',
        createdAt: now,
        updatedAt: now,
      ));

      // Delete one song
      await repository.deleteSong('delete-this');

      // Verify the other songs remain
      final remainingSongs = await repository.getSongsByConcert(concertId);
      expect(remainingSongs.length, 2);
      expect(remainingSongs.any((s) => s.id == 'keep-1'), isTrue);
      expect(remainingSongs.any((s) => s.id == 'keep-2'), isTrue);
      expect(remainingSongs.any((s) => s.id == 'delete-this'), isFalse);
    });

    test('data layer correctly converts between domain and drift models',
        () async {
      final now = DateTime.now();
      final domainSong = Song(
        id: 'conversion-test',
        concertId: 'test-concert',
        title: 'Conversion Test Song',
        createdAt: now,
        updatedAt: now,
      );

      // Create using domain entity
      await repository.createSong(domainSong);

      // Retrieve as domain entity
      final retrieved = await repository.getSongById('conversion-test');

      // Verify all fields match
      expect(retrieved, isNotNull);
      expect(retrieved!.id, domainSong.id);
      expect(retrieved.concertId, domainSong.concertId);
      expect(retrieved.title, domainSong.title);
      // SQLite stores DateTime with second precision, so compare accordingly
      expect(retrieved.createdAt.millisecondsSinceEpoch ~/ 1000,
          domainSong.createdAt.millisecondsSinceEpoch ~/ 1000);

      // Verify it's a proper domain entity (not a model)
      expect(retrieved.runtimeType, Song);
    });

    test('repository handles concurrent operations correctly', () async {
      final now = DateTime.now();
      const concertId = 'concurrent-test';

      // Create multiple songs concurrently
      final futures = List.generate(
        5,
        (index) => repository.createSong(
          Song(
            id: 'concurrent-$index',
            concertId: concertId,
            title: 'Concurrent Song $index',
            createdAt: now.add(Duration(milliseconds: index)),
            updatedAt: now.add(Duration(milliseconds: index)),
          ),
        ),
      );

      await Future.wait(futures);

      // Verify all songs were created
      final songs = await repository.getSongsByConcert(concertId);
      expect(songs.length, 5);

      // Verify each song exists
      for (int i = 0; i < 5; i++) {
        expect(songs.any((s) => s.id == 'concurrent-$i'), isTrue);
      }
    });

    test('soft delete does not permanently remove data', () async {
      final now = DateTime.now();
      final song = Song(
        id: 'soft-delete-test',
        concertId: 'test-concert',
        title: 'Soft Delete Test',
        createdAt: now,
        updatedAt: now,
      );

      // Create and delete the song
      await repository.createSong(song);
      await repository.deleteSong('soft-delete-test');

      // Song should not be retrievable through repository
      final retrieved = await repository.getSongById('soft-delete-test');
      expect(retrieved, isNull);

      // But it should still exist in the database (soft delete)
      // We can verify this by checking unsynced songs
      final unsynced = await dataSource.getUnsyncedSongs();
      expect(unsynced.any((s) => s.id == 'soft-delete-test'), isTrue);
    });
  });
}
