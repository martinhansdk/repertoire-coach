import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('FavoriteTrack', () {
    final dateTime = DateTime(2024, 1, 15);
    final track = Track(
      id: 'track-1',
      songId: 'song-1',
      name: 'Soprano',
      audioUrl: 'https://example.com/audio.mp3',
      storagePath: 'choirs/choir-1/tracks/track-1.mp3',
      durationMs: 180000,
      filePath: null,
      createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
    );

    test('creates instance with required fields', () {
      final favorite = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      expect(favorite.addedAt, dateTime);
      expect(favorite.track, track);
    });

    test('hasAudio delegates to track', () {
      final favoriteWithAudio = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final trackWithoutAudio = Track(
        id: 'track-2',
        songId: 'song-1',
        name: 'Alto',
        audioUrl: null,
        storagePath: null,
        durationMs: null,
        filePath: null,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final favoriteWithoutAudio = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: trackWithoutAudio,
      );

      expect(favoriteWithAudio.hasAudio, isTrue);
      expect(favoriteWithoutAudio.hasAudio, isFalse);
    });

    test('supports equality comparison', () {
      final favorite1 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final favorite2 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      expect(favorite1, equals(favorite2));
    });

    test('inequality when fields differ', () {
      final favorite1 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final differentTrack = Track(
        id: 'track-2',
        songId: 'song-1',
        name: 'Alto',
        audioUrl: 'https://example.com/audio2.mp3',
        storagePath: 'choirs/choir-1/tracks/track-2.mp3',
        durationMs: 150000,
        filePath: null,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final favorite2 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: differentTrack,
      );

      expect(favorite1, isNot(equals(favorite2)));
    });

    test('inequality when addedAt differs', () {
      final favorite1 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final favorite2 = FavoriteTrack(
        addedAt: DateTime(2024, 1, 20),
        updatedAt: DateTime(2024, 1, 20),
        track: track,
      );

      expect(favorite1, isNot(equals(favorite2)));
    });

    test('produces consistent hash codes for equal instances', () {
      final favorite1 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final favorite2 = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      expect(favorite1.hashCode, equals(favorite2.hashCode));
    });

    test('toString includes relevant information', () {
      final favorite = FavoriteTrack(
        addedAt: dateTime,
        updatedAt: dateTime,
        track: track,
      );

      final string = favorite.toString();
      expect(string, contains('FavoriteTrack'));
      expect(string, contains('addedAt'));
      expect(string, contains(track.name));
    });
  });
}
