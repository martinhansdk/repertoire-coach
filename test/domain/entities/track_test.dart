import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('Track Entity', () {
    test('should create a valid Track instance', () {
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

      // Assert
      expect(track.id, '1');
      expect(track.songId, 'song1');
      expect(track.name, 'Soprano');
      expect(track.audioUrl, 'https://example.com/track.mp3');
      expect(track.localPath, '/local/track.mp3');
      expect(track.duration, 180000);
      expect(track.createdAt, now);
    });

    test('should support null localPath', () {
      // Arrange
      final track = Track(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(track.localPath, isNull);
    });

    test('should support different track names', () {
      // Arrange
      final tracks = [
        Track(
          id: '1',
          songId: 'song1',
          name: 'Soprano',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        Track(
          id: '2',
          songId: 'song1',
          name: 'Full Choir',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        Track(
          id: '3',
          songId: 'song1',
          name: 'Instrumental',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
        Track(
          id: '4',
          songId: 'song1',
          name: 'Monday Runthrough',
          audioUrl: 'url',
          duration: 1000,
          createdAt: DateTime.now(),
        ),
      ];

      // Assert - all different track types are valid
      expect(tracks[0].name, 'Soprano');
      expect(tracks[1].name, 'Full Choir');
      expect(tracks[2].name, 'Instrumental');
      expect(tracks[3].name, 'Monday Runthrough');
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final track1 = Track(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );
      final track2 = Track(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );
      final track3 = Track(
        id: '2',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: now,
      );

      // Assert
      expect(track1, equals(track2));
      expect(track1, isNot(equals(track3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final track = Track(
        id: '1',
        songId: 'song1',
        name: 'Soprano',
        audioUrl: 'https://example.com/track.mp3',
        duration: 180000,
        createdAt: DateTime.now(),
      );

      // Act
      final result = track.toString();

      // Assert
      expect(result, contains('Track'));
      expect(result, contains('id: 1'));
      expect(result, contains('songId: song1'));
      expect(result, contains('name: Soprano'));
      expect(result, contains('duration: 180000ms'));
    });
  });
}
