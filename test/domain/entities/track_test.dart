import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('Track Entity', () {
    final now = DateTime(2025, 1, 15, 10, 30);
    final track = Track(
      id: 'track-1',
      songId: 'song-1',
      name: 'Soprano Part',
      voicePart: 'Soprano',
      filePath: '/path/to/audio.mp3',
      createdAt: now,
      updatedAt: now,
    );

    test('should create Track with all required fields', () {
      expect(track.id, 'track-1');
      expect(track.songId, 'song-1');
      expect(track.name, 'Soprano Part');
      expect(track.voicePart, 'Soprano');
      expect(track.filePath, '/path/to/audio.mp3');
      expect(track.createdAt, now);
      expect(track.updatedAt, now);
    });

    test('should create Track without filePath', () {
      final trackWithoutFilePath = Track(
        id: 'track-2',
        songId: 'song-1',
        name: 'Alto Part',
        voicePart: 'Alto',
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
        voicePart: 'Soprano',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      final track2 = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        voicePart: 'Soprano',
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
        voicePart: 'Soprano',
        filePath: '/path/to/audio.mp3',
        createdAt: now,
        updatedAt: now,
      );

      final track2 = Track(
        id: 'track-2', // Different ID
        songId: 'song-1',
        name: 'Soprano Part',
        voicePart: 'Soprano',
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
      expect(trackString, contains('Soprano'));
    });

    test('should support different voice parts', () {
      final voiceParts = ['Soprano', 'Alto', 'Tenor', 'Bass', 'Choir', 'Instrumental'];

      for (final voicePart in voiceParts) {
        final track = Track(
          id: 'track-$voicePart',
          songId: 'song-1',
          name: '$voicePart Part',
          voicePart: voicePart,
          filePath: null,
          createdAt: now,
          updatedAt: now,
        );

        expect(track.voicePart, voicePart);
      }
    });

    test('should handle updatedAt being different from createdAt', () {
      final createdAt = DateTime(2025, 1, 15, 10, 0);
      final updatedAt = DateTime(2025, 1, 15, 11, 0);

      final track = Track(
        id: 'track-1',
        songId: 'song-1',
        name: 'Soprano Part',
        voicePart: 'Soprano',
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
