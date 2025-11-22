import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/song_model.dart';
import 'package:repertoire_coach/domain/entities/song.dart';

void main() {
  group('SongModel', () {
    test('should be a subclass of Song entity', () {
      // Arrange
      final now = DateTime.now();
      final songModel = SongModel(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(songModel, isA<Song>());
    });

    test('should create SongModel from Song entity', () {
      // Arrange
      final now = DateTime.now();
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final songModel = SongModel.fromEntity(song);

      // Assert
      expect(songModel.id, song.id);
      expect(songModel.concertId, song.concertId);
      expect(songModel.title, song.title);
      expect(songModel.createdAt, song.createdAt);
      expect(songModel.updatedAt, song.updatedAt);
    });

    test('should convert SongModel to Song entity', () {
      // Arrange
      final now = DateTime.now();
      final songModel = SongModel(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final song = songModel.toEntity();

      // Assert
      expect(song, isA<Song>());
      expect(song.id, songModel.id);
      expect(song.concertId, songModel.concertId);
      expect(song.title, songModel.title);
      expect(song.createdAt, songModel.createdAt);
      expect(song.updatedAt, songModel.updatedAt);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final songModel1 = SongModel(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );
      final songModel2 = SongModel(
        id: '1',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );
      final songModel3 = SongModel(
        id: '2',
        concertId: 'concert1',
        title: 'Amazing Grace',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(songModel1, equals(songModel2));
      expect(songModel1, isNot(equals(songModel3)));
    });

    test('should maintain all properties through entity conversion', () {
      // Arrange
      final now = DateTime.now();
      final originalSong = Song(
        id: 'song123',
        concertId: 'concert456',
        title: 'How Great Thou Art',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final songModel = SongModel.fromEntity(originalSong);
      final convertedSong = songModel.toEntity();

      // Assert
      expect(convertedSong, equals(originalSong));
    });
  });
}
