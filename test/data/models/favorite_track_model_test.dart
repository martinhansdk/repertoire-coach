import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/favorite_track_model.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';

void main() {
  group('FavoriteTrackModel', () {
    final dateTime = DateTime(2024, 1, 15);

    group('fromEntity', () {
      test('converts entity to model', () {
        final entity = FavoriteTrack(
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

        final model = FavoriteTrackModel.fromEntity(entity);

        expect(model.userId, entity.userId);
        expect(model.trackId, entity.trackId);
        expect(model.songId, entity.songId);
        expect(model.addedAt, entity.addedAt);
        expect(model.trackName, entity.trackName);
        expect(model.songTitle, entity.songTitle);
        expect(model.choirName, entity.choirName);
        expect(model.audioUrl, entity.audioUrl);
        expect(model.durationMs, entity.durationMs);
      });
    });

    group('toEntity', () {
      test('converts model to entity', () {
        final model = FavoriteTrackModel(
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

        final entity = model.toEntity();

        expect(entity.userId, model.userId);
        expect(entity.trackId, model.trackId);
        expect(entity.songId, model.songId);
        expect(entity.addedAt, model.addedAt);
        expect(entity.trackName, model.trackName);
        expect(entity.songTitle, model.songTitle);
        expect(entity.choirName, model.choirName);
        expect(entity.audioUrl, model.audioUrl);
        expect(entity.durationMs, model.durationMs);
      });

      test('handles null optional fields', () {
        final model = FavoriteTrackModel(
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

        final entity = model.toEntity();

        expect(entity.audioUrl, isNull);
        expect(entity.durationMs, isNull);
      });
    });

    group('toDriftCompanion', () {
      test('creates companion with core values only', () {
        final model = FavoriteTrackModel(
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

        final companion = model.toDriftCompanion();

        expect(companion.userId.value, 'user-1');
        expect(companion.trackId.value, 'track-1');
        expect(companion.songId.value, 'song-1');
        expect(companion.addedAt.value, dateTime);
        // Denormalized fields are not included in companion
      });
    });

    group('fromJson', () {
      test('deserializes from JSON with all fields', () {
        final json = {
          'user_id': 'user-1',
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'track_name': 'Soprano',
          'song_title': 'Amazing Grace',
          'choir_name': 'City Choir',
          'audio_url': 'https://example.com/audio.mp3',
          'duration_ms': 180000,
        };

        final model = FavoriteTrackModel.fromJson(json);

        expect(model.userId, 'user-1');
        expect(model.trackId, 'track-1');
        expect(model.songId, 'song-1');
        expect(model.addedAt, dateTime);
        expect(model.trackName, 'Soprano');
        expect(model.songTitle, 'Amazing Grace');
        expect(model.choirName, 'City Choir');
        expect(model.audioUrl, 'https://example.com/audio.mp3');
        expect(model.durationMs, 180000);
      });

      test('handles null optional fields', () {
        final json = {
          'user_id': 'user-1',
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'track_name': 'Soprano',
          'song_title': 'Amazing Grace',
          'choir_name': 'City Choir',
          'audio_url': null,
          'duration_ms': null,
        };

        final model = FavoriteTrackModel.fromJson(json);

        expect(model.audioUrl, isNull);
        expect(model.durationMs, isNull);
      });
    });

    group('toJson', () {
      test('serializes to JSON with core fields only', () {
        final model = FavoriteTrackModel(
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

        final json = model.toJson();

        // toJson only returns core fields for Supabase writes
        expect(json['user_id'], 'user-1');
        expect(json['track_id'], 'track-1');
        expect(json['song_id'], 'song-1');
        expect(json['added_at'], dateTime.toIso8601String());

        // Denormalized fields are not included (computed by Supabase queries)
        expect(json.containsKey('track_name'), isFalse);
        expect(json.containsKey('song_title'), isFalse);
        expect(json.containsKey('choir_name'), isFalse);
        expect(json.containsKey('audio_url'), isFalse);
        expect(json.containsKey('duration_ms'), isFalse);
      });

      test('always returns only core fields', () {
        final model = FavoriteTrackModel(
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

        final json = model.toJson();

        // Only core fields present
        expect(json.keys.length, 4);
        expect(json.keys, containsAll(['user_id', 'track_id', 'song_id', 'added_at']));
      });
    });

    group('roundtrip conversions', () {
      test('entity -> model -> entity preserves data', () {
        final original = FavoriteTrack(
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

        final roundtrip = FavoriteTrackModel.fromEntity(original).toEntity();

        expect(roundtrip, equals(original));
      });

      test('fromJson reads all fields, toJson returns core fields only', () {
        final fullJson = {
          'user_id': 'user-1',
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'track_name': 'Soprano',
          'song_title': 'Amazing Grace',
          'choir_name': 'City Choir',
          'audio_url': 'https://example.com/audio.mp3',
          'duration_ms': 180000,
        };

        final model = FavoriteTrackModel.fromJson(fullJson);
        final coreJson = model.toJson();

        // fromJson reads all fields
        expect(model.trackName, 'Soprano');
        expect(model.songTitle, 'Amazing Grace');
        expect(model.choirName, 'City Choir');

        // toJson returns only core fields
        expect(coreJson.keys.length, 4);
        expect(coreJson['user_id'], 'user-1');
        expect(coreJson['track_id'], 'track-1');
        expect(coreJson['song_id'], 'song-1');
        expect(coreJson['added_at'], dateTime.toIso8601String());
      });
    });
  });
}
