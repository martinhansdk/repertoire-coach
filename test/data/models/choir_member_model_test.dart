import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/choir_member_model.dart';
import 'package:repertoire_coach/domain/entities/choir_member.dart';

void main() {
  final now = DateTime.now();
  final tChoirMemberModel = ChoirMemberModel(
    choirId: 'c1',
    userId: 'u1',
    joinedAt: now,
  );

  final tChoirMember = ChoirMember(
    choirId: 'c1',
    userId: 'u1',
    joinedAt: now,
  );

  test('should be a subclass of ChoirMember entity', () async {
    expect(tChoirMemberModel, isA<ChoirMember>());
  });

  group('fromEntity', () {
    test('should return a valid model from a ChoirMember entity', () {
      // act
      final result = ChoirMemberModel.fromEntity(tChoirMember);
      // assert
      expect(result, tChoirMemberModel);
    });
  });

  group('toEntity', () {
    test('should return a valid ChoirMember entity from a model', () {
      // act
      final result = tChoirMemberModel.toEntity();
      // assert
      expect(result, tChoirMember);
    });
  });

  group('fromJson', () {
    test('should return a valid model from JSON', () async {
      // arrange
      final Map<String, dynamic> jsonMap = {
        'choir_id': 'c1',
        'user_id': 'u1',
        'joined_at': now.toIso8601String(),
      };
      // act
      final result = ChoirMemberModel.fromJson(jsonMap);
      // assert
      expect(result, tChoirMemberModel);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () async {
      // act
      final result = tChoirMemberModel.toJson();
      // assert
      final expectedMap = {
        'choir_id': 'c1',
        'user_id': 'u1',
        'joined_at': now.toIso8601String(),
      };
      expect(result, expectedMap);
    });
  });
}
