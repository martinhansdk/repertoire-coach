import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';

void main() {
  group('MarkerSetModel', () {
    test('should be a subclass of MarkerSet entity', () {
      // Arrange
      final now = DateTime.now();
      final markerSetModel = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(markerSetModel, isA<MarkerSet>());
    });

    test('should create MarkerSetModel from MarkerSet entity', () {
      // Arrange
      final now = DateTime.now();
      final markerSet = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final markerSetModel = MarkerSetModel.fromEntity(markerSet);

      // Assert
      expect(markerSetModel.id, markerSet.id);
      expect(markerSetModel.trackId, markerSet.trackId);
      expect(markerSetModel.name, markerSet.name);
      expect(markerSetModel.isShared, markerSet.isShared);
      expect(markerSetModel.createdByUserId, markerSet.createdByUserId);
      expect(markerSetModel.createdAt, markerSet.createdAt);
      expect(markerSetModel.updatedAt, markerSet.updatedAt);
    });

    test('should convert MarkerSetModel to MarkerSet entity', () {
      // Arrange
      final now = DateTime.now();
      final markerSetModel = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final markerSet = markerSetModel.toEntity();

      // Assert
      expect(markerSet, isA<MarkerSet>());
      expect(markerSet.id, markerSetModel.id);
      expect(markerSet.trackId, markerSetModel.trackId);
      expect(markerSet.name, markerSetModel.name);
      expect(markerSet.isShared, markerSetModel.isShared);
      expect(markerSet.createdByUserId, markerSetModel.createdByUserId);
      expect(markerSet.createdAt, markerSetModel.createdAt);
      expect(markerSet.updatedAt, markerSetModel.updatedAt);
    });

    test('should support shared marker sets', () {
      // Arrange
      final markerSetModel = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(markerSetModel.isShared, true);
    });

    test('should support private marker sets', () {
      // Arrange
      final markerSetModel = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'My Practice Markers',
        isShared: false,
        isTimeSynced: false,
        createdByUserId: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(markerSetModel.isShared, false);
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final markerSetModel1 = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );
      final markerSetModel2 = MarkerSetModel(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );
      final markerSetModel3 = MarkerSetModel(
        id: '2',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(markerSetModel1, equals(markerSetModel2));
      expect(markerSetModel1, isNot(equals(markerSetModel3)));
    });

    group('fromJson', () {
      test('should default isTimeSynced to true when missing from JSON', () {
        // Regression: Bug 2 - when is_time_synced was omitted from the
        // remote SELECT, fromJson defaulted it to true, causing marker
        // sets with isTimeSynced=false to appear "synced to 0:00".
        final now = DateTime.now().toUtc();
        final json = {
          'id': 'ms-1',
          'track_id': 'track-1',
          'name': 'My Markers',
          'is_shared': false,
          // 'is_time_synced' is intentionally omitted
          'created_by_user_id': 'user-1',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final model = MarkerSetModel.fromJson(json);

        // Documents the default behavior - missing field defaults to true
        expect(model.isTimeSynced, isTrue);
      });

      test('should preserve isTimeSynced: false when present in JSON', () {
        // Regression: ensures that when is_time_synced IS included in the
        // SELECT, the false value is preserved through deserialization.
        final now = DateTime.now().toUtc();
        final json = {
          'id': 'ms-1',
          'track_id': 'track-1',
          'name': 'My Markers',
          'is_shared': false,
          'is_time_synced': false,
          'created_by_user_id': 'user-1',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        final model = MarkerSetModel.fromJson(json);

        expect(model.isTimeSynced, isFalse);
      });
    });

    test('should maintain all properties through entity conversion', () {
      // Arrange
      final now = DateTime.now();
      final originalMarkerSet = MarkerSet(
        id: 'markerset123',
        trackId: 'track456',
        name: 'Performance Sections',
        isShared: true,
        isTimeSynced: true,
        createdByUserId: 'user789',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final markerSetModel = MarkerSetModel.fromEntity(originalMarkerSet);
      final convertedMarkerSet = markerSetModel.toEntity();

      // Assert
      expect(convertedMarkerSet, equals(originalMarkerSet));
    });
  });
}
