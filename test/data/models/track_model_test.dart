import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/track_model.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

void main() {
  final now = DateTime.now();
  final tTrackModel = TrackModel(
    id: 't1',
    songId: 's1',
    name: 'Test Track',
    filePath: '/path/to/file.mp3',
    createdAt: now,
    updatedAt: now,
  );

  final tTrack = Track(
    id: 't1',
    songId: 's1',
    name: 'Test Track',
    filePath: '/path/to/file.mp3',
    createdAt: now,
    updatedAt: now,
  );

  test('should be a subclass of Track entity', () async {
    expect(tTrackModel, isA<Track>());
  });

  group('fromEntity', () {
    test('should return a valid model from a Track entity', () {
      // act
      final result = TrackModel.fromEntity(tTrack);
      // assert
      expect(result, tTrackModel);
    });
  });

  group('toEntity', () {
    test('should return a valid Track entity from a model', () {
      // act
      final result = tTrackModel.toEntity();
      // assert
      expect(result, tTrack);
    });
  });

  group('fromJson', () {
    test('should return a valid model from JSON', () async {
      // arrange
      final Map<String, dynamic> jsonMap = {
        'id': 't1',
        'song_id': 's1',
        'name': 'Test Track',
        'file_path': '/path/to/file.mp3',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      // act
      final result = TrackModel.fromJson(jsonMap);
      // assert
      expect(result, tTrackModel);
    });

    test('should return a valid model from JSON with null file_path', () async {
      // arrange
      final tTrackModelWithNullPath = TrackModel(
        id: 't1',
        songId: 's1',
        name: 'Test Track',
        filePath: null,
        createdAt: now,
        updatedAt: now,
      );
      final Map<String, dynamic> jsonMap = {
        'id': 't1',
        'song_id': 's1',
        'name': 'Test Track',
        'file_path': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      // act
      final result = TrackModel.fromJson(jsonMap);
      // assert
      expect(result, tTrackModelWithNullPath);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () async {
      // act
      final result = tTrackModel.toJson();
      // assert
      final expectedMap = {
        'id': 't1',
        'song_id': 's1',
        'name': 'Test Track',
        'file_path': '/path/to/file.mp3',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      expect(result, expectedMap);
    });
  });
}
