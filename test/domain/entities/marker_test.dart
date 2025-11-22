import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';

void main() {
  group('Marker Entity', () {
    test('should create a valid Marker instance', () {
      // Arrange
      final now = DateTime.now();
      final marker = Marker(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );

      // Assert
      expect(marker.id, '1');
      expect(marker.markerSetId, 'set1');
      expect(marker.label, 'Verse 1');
      expect(marker.positionMs, 30000);
      expect(marker.order, 1);
      expect(marker.createdAt, now);
    });

    test('should support marker at beginning', () {
      // Arrange
      final marker = Marker(
        id: '1',
        markerSetId: 'set1',
        label: 'Start',
        positionMs: 0,
        order: 0,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(marker.positionMs, 0);
      expect(marker.order, 0);
    });

    test('should support different label types', () {
      // Arrange
      final markers = [
        Marker(
          id: '1',
          markerSetId: 'set1',
          label: 'Intro',
          positionMs: 0,
          order: 0,
          createdAt: DateTime.now(),
        ),
        Marker(
          id: '2',
          markerSetId: 'set1',
          label: 'Bar 25',
          positionMs: 30000,
          order: 1,
          createdAt: DateTime.now(),
        ),
        Marker(
          id: '3',
          markerSetId: 'set1',
          label: '1:15',
          positionMs: 75000,
          order: 2,
          createdAt: DateTime.now(),
        ),
      ];

      // Assert - all different label types are valid
      expect(markers[0].label, 'Intro');
      expect(markers[1].label, 'Bar 25');
      expect(markers[2].label, '1:15');
    });

    test('should support equality comparison', () {
      // Arrange
      final now = DateTime.now();
      final marker1 = Marker(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );
      final marker2 = Marker(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );
      final marker3 = Marker(
        id: '2',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );

      // Assert
      expect(marker1, equals(marker2));
      expect(marker1, isNot(equals(marker3)));
    });

    test('should have correct toString implementation', () {
      // Arrange
      final marker = Marker(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: DateTime.now(),
      );

      // Act
      final result = marker.toString();

      // Assert
      expect(result, contains('Marker'));
      expect(result, contains('id: 1'));
      expect(result, contains('label: Verse 1'));
      expect(result, contains('positionMs: 30000ms'));
      expect(result, contains('order: 1'));
    });
  });
}
