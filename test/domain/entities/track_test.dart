import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('Track Entity', () {
    final now = DateTime(2025, 1, 15, 10, 30);
    final track = Track(
      id: 'track-1',
      songId: 'song-1',
      name: 'Soprano Part',
      filePath: '/path/to/audio.mp3',
      createdAt: now,
      updatedAt: now,
    );

    test('should create Track with all required fields', () {
      expect(track.id, 'track-1');
      expect(track.songId, 'song-1');
      expect(track.name, 'Soprano Part');
      expect(track.filePath, '/path/to/audio.mp3');
      expect(track.createdAt, now);
      expect(track.updatedAt, now);
    });

    test('should create Track without filePath', () {
      final trackWithoutFilePath = Track(
        id: 'track-2',
        songId: 'song-1',
        name: 'Alto Part',
        filePath: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(trackWithoutFilePath.filePath, isNull);
    });

    test('should support equality comparison', () {
      final track1 = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      final track2 = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      expect(track1, equals(track2));
    });

    test('should not be equal if any field differs', () {
      final track1 = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      final track2 = Track(
        id: 'track-2', // Different ID
        songId: 'song-1',
        name: 'Soprano Part',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      expect(track1, isNot(equals(track2)));
    });

    test('should have correct toString representation', () {
      final trackString = track.toString();
      expect(trackString, contains('track-1'));
      expect(trackString, contains('song-1'));
      expect(trackString, contains('Soprano Part'));
    });

    test('should support different track names', () {
      final trackNames = ['Soprano Part', 'Alto Part', 'Tenor Part', 'Bass Part', 'Full Choir', 'Instrumental'];

      for (final name in trackNames) {
        final track = Track(
          id: 'track-$name',
          songId: 'song-1',
          name: name,
          filePath: null,
          createdAt: now,
          updatedAt: now,
        );

        expect(track.name, name);
      }
    });

    test('should handle updatedAt being different from createdAt', () {
      final createdAt = DateTime(2025, 1, 15, 10, 0);
      final updatedAt = DateTime(2025, 1, 15, 11, 0);

      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        filePath: null,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(track.createdAt, createdAt);
      expect(track.updatedAt, updatedAt);
      expect(track.updatedAt.isAfter(track.createdAt), isTrue);
    });
  });
}
