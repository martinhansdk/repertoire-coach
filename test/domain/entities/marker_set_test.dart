import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';

void main() {
  group('MarkerSet Entity', () {
    test('should create a valid shared MarkerSet instance', () {
      // Arrange
      final now = DateTime.now();
      final markerSet = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(markerSet.id, '1');
      expect(markerSet.trackId, 'track1');
      expect(markerSet.name, 'Musical Structure');
      expect(markerSet.isShared, true);
      expect(markerSet.createdByUserId, 'user1');
      expect(markerSet.createdAt, now);
      expect(markerSet.updatedAt, now);
    });

    test('should create a valid private MarkerSet instance', () {
      // Arrange
      final markerSet = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'My Practice Markers',
        isShared: false,
        createdByUserId: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Assert
      expect(markerSet.isShared, false);
      expect(markerSet.name, 'My Practice Markers');
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final markerSet1 = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );
      final markerSet2 = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );
      final markerSet3 = MarkerSet(
        id: '2',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        createdByUserId: 'user1',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(markerSet1, equals(markerSet2));
      expect(markerSet1, isNot(equals(markerSet3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final markerSet = MarkerSet(
        id: '1',
        trackId: 'track1',
        name: 'Musical Structure',
        isShared: true,
        createdByUserId: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final result = markerSet.toString();

      // Assert
      expect(result, contains('MarkerSet'));
      expect(result, contains('id: 1'));
      expect(result, contains('trackId: track1'));
      expect(result, contains('name: Musical Structure'));
      expect(result, contains('isShared: true'));
    });
  });
}
