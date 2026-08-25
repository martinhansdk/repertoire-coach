import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';

void main() {
  final now = DateTime.now();
  final tConcertModel = ConcertModel(
    id: 'c1',
    choirId: 'choir1',
    choirName: 'Test Choir',
    name: 'Test Concert',
    concertDate: now,
    createdAt: now,
        updatedAt: now,
  );

  final tConcert = Concert(
    id: 'c1',
    choirId: 'choir1',
    choirName: 'Test Choir',
    name: 'Test Concert',
    concertDate: now,
    createdAt: now,
  );

  test('should be a subclass of Concert entity', () async {
    expect(tConcertModel, isA<Concert>());
  });

  group('fromEntity', () {
    test('should return a valid model from a Concert entity', () {
      // act
      final result = ConcertModel.fromEntity(tConcert);
      // assert
      expect(result, tConcertModel);
    });
  });

  group('toEntity', () {
    test('should return a valid Concert entity from a model', () {
      // act
      final result = tConcertModel.toEntity();
      // assert
      expect(result, tConcert);
    });
  });

  group('fromJson', () {
    test('should return a valid model from JSON', () async {
      // arrange
      final Map<String, dynamic> jsonMap = {
        'id': 'c1',
        'choir_id': 'choir1',
        'choir_name': 'Test Choir',
        'name': 'Test Concert',
        'concert_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };
      // act
      final result = ConcertModel.fromJson(jsonMap);
      // assert
      expect(result, tConcertModel);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () async {
      // act
      final result = tConcertModel.toJson();
      // assert
      // Note: choir_name is not included in toJson as it's a read-only
      // computed field from a join with the choirs table
      final expectedMap = {
        'id': 'c1',
        'choir_id': 'choir1',
        'name': 'Test Concert',
        'concert_date': now.toIso8601String(),
        'created_at': now.toUtc().toIso8601String(),
        'deleted': false,
      };
      expect(result, expectedMap);
    });
  });
}
