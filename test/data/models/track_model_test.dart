import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/track_model.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('TrackModel', () {
    test('should be a subclass of Track entity', () {
      // Arrange
      final trackModel = TrackModel(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(trackModel, isA<Track>());
    });

    test('should create TrackModel from Track entity', () {
      // Arrange
      final now = DateTime.now();
      final track = Track(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        localPath: '/local/track.mp3',
        duration: 180000,
        createdAt: now,
      );

      // Act
      final trackModel = TrackModel.fromEntity(track);

      // Assert
      expect(trackModel.id, track.id);
      expect(trackModel.songId, track.songId);
      expect(trackModel.name, track.name);
      expect(trackModel.audioUrl, track.audioUrl);
      expect(trackModel.localPath, track.localPath);
      expect(trackModel.duration, track.duration);
      expect(trackModel.createdAt, track.createdAt);
    });

    test('should convert TrackModel to Track entity', () {
      // Arrange
      final now = DateTime.now();
      final trackModel = TrackModel(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );

      // Act
      final track = trackModel.toEntity();

      // Assert
      expect(track, isA<Track>());
      expect(track.id, trackModel.id);
      expect(track.songId, trackModel.songId);
      expect(track.name, trackModel.name);
      expect(track.audioUrl, trackModel.audioUrl);
      expect(track.duration, trackModel.duration);
      expect(track.createdAt, trackModel.createdAt);
    });

    test('should handle null localPath', () {
      // Arrange
      final trackModel = TrackModel(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(trackModel.localPath, isNull);
    });

    test('should support different track names without type field', () {
      // Arrange - Track uses only name field, no type enum
      final tracks = [
        TrackModel(
          id: '1',
          songId: 'song1',
          name: 'Soprano',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        TrackModel(
          id: '2',
          songId: 'song1',
          name: 'Full Choir',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        TrackModel(
          id: '3',
          songId: 'song1',
          name: 'Instrumental',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        TrackModel(
          id: '4',
          songId: 'song1',
          name: 'Monday Runthrough',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
      ];

      // Assert - all different track names are valid
      expect(tracks[0].name, 'Soprano');
      expect(tracks[1].name, 'Full Choir');
      expect(tracks[2].name, 'Instrumental');
      expect(tracks[3].name, 'Monday Runthrough');
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final trackModel1 = TrackModel(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );
      final trackModel2 = TrackModel(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );
      final trackModel3 = TrackModel(
        id: '2',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );

      // Assert
      expect(trackModel1, equals(trackModel2));
      expect(trackModel1, isNot(equals(trackModel3)));
    });

    test('should maintain all properties through entity conversion', () {
      // Arrange
      final now = DateTime.now();
      final originalTrack = Track(
        id: 'track123',
        songId: 'song456',
        name: 'Tenor',
        audioUrl: 'https://example.com/tenor.mp3',
        localPath: '/storage/tenor.mp3',
        duration: 240000,
        createdAt: now,
      );

      // Act
      final trackModel = TrackModel.fromEntity(originalTrack);
      final convertedTrack = trackModel.toEntity();

      // Assert
      expect(convertedTrack, equals(originalTrack));
    });
  });
}
