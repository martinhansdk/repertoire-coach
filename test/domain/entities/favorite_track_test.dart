import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';

void main() {
  group('FavoriteTrack', () {
    final dateTime = DateTime(2024, 1, 15);

    test('creates instance with all fields', () {
      final favorite = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      expect(favorite.userId, 'user-1');
      expect(favorite.trackId, 'track-1');
      expect(favorite.songId, 'song-1');
      expect(favorite.addedAt, dateTime);
      expect(favorite.trackName, 'Soprano');
      expect(favorite.songTitle, 'Amazing Grace');
      expect(favorite.choirName, 'City Choir');
      expect(favorite.audioUrl, 'https://example.com/audio.mp3');
      expect(favorite.durationMs, 180000);
    });

    test('creates instance with null optional fields', () {
      final favorite = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: null,
        durationMs: null,
      );

      expect(favorite.audioUrl, isNull);
      expect(favorite.durationMs, isNull);
    });

    test('supports equality comparison', () {
      final favorite1 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      final favorite2 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      expect(favorite1, equals(favorite2));
    });

    test('inequality when fields differ', () {
      final favorite1 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      final favorite2 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-2', // Different track ID
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Alto',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      expect(favorite1, isNot(equals(favorite2)));
    });

    test('produces consistent hash codes for equal instances', () {
      final favorite1 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      final favorite2 = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: dateTime,
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );

      expect(favorite1.hashCode, equals(favorite2.hashCode));
    });
  });
}
