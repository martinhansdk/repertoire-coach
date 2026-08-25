import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/favorite_track_model.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  group('FavoriteTrackModel', () {
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

    group('fromEntity', () {
      test('converts entity to model', () {
        final entity = FavoriteTrack(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final model = FavoriteTrackModel.fromEntity(entity);

        expect(model.addedAt, entity.addedAt);
        expect(model.track, entity.track);
      });
    });

    group('toEntity', () {
      test('converts model to entity', () {
        final model = FavoriteTrackModel(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final entity = model.toEntity();

        expect(entity.addedAt, model.addedAt);
        expect(entity.track, model.track);
      });
    });

    group('toDriftCompanion', () {
      test('creates companion with core values extracted from track', () {
        final model = FavoriteTrackModel(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final companion = model.toDriftCompanion('user-1');

        expect(companion.userId.value, 'user-1');
        expect(companion.trackId.value, 'track-1');
        expect(companion.songId.value, 'song-1');
        expect(companion.addedAt.value, dateTime);
      });
    });

    group('fromJson', () {
      test('deserializes from JSON with track data', () {
        final json = {
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'updated_at': dateTime.toIso8601String(),
          'tracks': {
            'name': 'Soprano',
            'audio_url': 'https://example.com/audio.mp3',
            'storage_path': 'choirs/choir-1/tracks/track-1.mp3',
            'duration_ms': 180000,
            'created_at': '2024-01-01T00:00:00.000',
          },
        };

        final model = FavoriteTrackModel.fromJson(json);

        expect(model.addedAt, dateTime);
        expect(model.track.id, 'track-1');
        expect(model.track.songId, 'song-1');
        expect(model.track.name, 'Soprano');
        expect(model.track.audioUrl, 'https://example.com/audio.mp3');
        expect(model.track.storagePath, 'choirs/choir-1/tracks/track-1.mp3');
        expect(model.track.durationMs, 180000);
        expect(model.track.createdAt, DateTime.parse('2024-01-01T00:00:00.000'));
        expect(model.track.updatedAt, DateTime.parse('2024-01-01T00:00:00.000')); // Same as created_at
      });

      test('handles null optional track fields', () {
        final json = {
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'updated_at': dateTime.toIso8601String(),
          'tracks': {
            'name': 'Soprano',
            'audio_url': null,
            'storage_path': null,
            'duration_ms': null,
            'created_at': '2024-01-01T00:00:00.000',
          },
        };

        final model = FavoriteTrackModel.fromJson(json);

        expect(model.track.audioUrl, isNull);
        expect(model.track.storagePath, isNull);
        expect(model.track.durationMs, isNull);
      });

      test('falls back to added_at when updated_at is missing', () {
        final json = {
          'track_id': 'track-1',
          'song_id': 'song-1',
          'added_at': dateTime.toIso8601String(),
          'updated_at': null,
          'tracks': {
            'name': 'Soprano',
            'audio_url': 'https://example.com/audio.mp3',
            'storage_path': 'choirs/choir-1/tracks/track-1.mp3',
            'duration_ms': 180000,
            'created_at': '2024-01-01T00:00:00.000',
          },
        };

        final model = FavoriteTrackModel.fromJson(json);

        expect(model.updatedAt, dateTime);
      });
    });

    group('toJson', () {
      test('serializes to JSON with core fields extracted from track', () {
        final model = FavoriteTrackModel(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final json = model.toJson('user-1');

        // toJson returns core fields for Supabase writes
        expect(json['user_id'], 'user-1');
        expect(json['track_id'], 'track-1');
        expect(json['song_id'], 'song-1');
        expect(json['added_at'], dateTime.toUtc().toIso8601String());

        // Track fields are not included (already in tracks table)
        expect(json.containsKey('track_name'), isFalse);
        expect(json.containsKey('audio_url'), isFalse);
        expect(json.containsKey('storage_path'), isFalse);
      });

      test('always returns only core fields', () {
        final model = FavoriteTrackModel(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final json = model.toJson('user-1');

        // Only core fields present
        expect(json.keys.length, 6);
        expect(json.keys, containsAll(['user_id', 'track_id', 'song_id', 'added_at', 'updated_at', 'deleted']));
      });
    });

    group('roundtrip conversions', () {
      test('entity -> model -> entity preserves data', () {
        final original = FavoriteTrack(
          addedAt: dateTime,
        updatedAt: dateTime,
          track: track,
        );

        final roundtrip = FavoriteTrackModel.fromEntity(original).toEntity();

        expect(roundtrip, equals(original));
      });
    });
  });
}
