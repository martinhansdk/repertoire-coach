import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/choir_model.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';

void main() {
  final now = DateTime.now();
  final tChoirModel = ChoirModel(
    id: 'c1',
    name: 'Test Choir',
    ownerId: 'u1',
    createdAt: now,
  );

  final tChoir = Choir(
    id: 'c1',
    name: 'Test Choir',
    ownerId: 'u1',
    createdAt: now,
  );

  test('should be a subclass of Choir entity', () async {
    expect(tChoirModel, isA<Choir>());
  });

  group('fromEntity', () {
    test('should return a valid model from a Choir entity', () {
      // act
      final result = ChoirModel.fromEntity(tChoir);
      // assert
      expect(result, tChoirModel);
    });
  });

  group('toEntity', () {
    test('should return a valid Choir entity from a model', () {
      // act
      final result = tChoirModel.toEntity();
      // assert
      expect(result, tChoir);
    });
  });

  group('fromJson', () {
    test('should return a valid model from JSON', () async {
      // arrange
      final Map<String, dynamic> jsonMap = {
        'id': 'c1',
        'name': 'Test Choir',
        'owner_id': 'u1',
        'created_at': now.toIso8601String(),
      };
      // act
      final result = ChoirModel.fromJson(jsonMap);
      // assert
      expect(result, tChoirModel);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () async {
      // act
      final result = tChoirModel.toJson();
      // assert
      final expectedMap = {
        'id': 'c1',
        'name': 'Test Choir',
        'owner_id': 'u1',
        'created_at': now.toIso8601String(),
      };
      expect(result, expectedMap);
    });
  });
}
