import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/models/marker_model.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';

void main() {
  group('MarkerModel', () {
    test('should be a subclass of Marker entity', () {
      // Arrange
      final markerModel = MarkerModel(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(markerModel, isA<Marker>());
    });

    test('should create MarkerModel from Marker entity', () {
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

      // Act
      final markerModel = MarkerModel.fromEntity(marker);

      // Assert
      expect(markerModel.id, marker.id);
      expect(markerModel.markerSetId, marker.markerSetId);
      expect(markerModel.label, marker.label);
      expect(markerModel.positionMs, marker.positionMs);
      expect(markerModel.order, marker.order);
      expect(markerModel.createdAt, marker.createdAt);
    });

    test('should convert MarkerModel to Marker entity', () {
      // Arrange
      final now = DateTime.now();
      final markerModel = MarkerModel(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );

      // Act
      final marker = markerModel.toEntity();

      // Assert
      expect(marker, isA<Marker>());
      expect(marker.id, markerModel.id);
      expect(marker.markerSetId, markerModel.markerSetId);
      expect(marker.label, markerModel.label);
      expect(marker.positionMs, markerModel.positionMs);
      expect(marker.order, markerModel.order);
      expect(marker.createdAt, markerModel.createdAt);
    });

    test('should support marker at beginning', () {
      // Arrange
      final markerModel = MarkerModel(
        id: '1',
        markerSetId: 'set1',
        label: 'Start',
        positionMs: 0,
        order: 0,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(markerModel.positionMs, 0);
      expect(markerModel.order, 0);
    });

    test('should support different label types', () {
      // Arrange
      final markers = [
        MarkerModel(
          id: '1',
          markerSetId: 'set1',
          label: 'Intro',
          positionMs: 0,
          order: 0,
          createdAt: DateTime.now(),
        ),
        MarkerModel(
          id: '2',
          markerSetId: 'set1',
          label: 'Bar 25',
          positionMs: 30000,
          order: 1,
          createdAt: DateTime.now(),
        ),
        MarkerModel(
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
      final markerModel1 = MarkerModel(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );
      final markerModel2 = MarkerModel(
        id: '1',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );
      final markerModel3 = MarkerModel(
        id: '2',
        markerSetId: 'set1',
        label: 'Verse 1',
        positionMs: 30000,
        order: 1,
        createdAt: now,
      );

      // Assert
      expect(markerModel1, equals(markerModel2));
      expect(markerModel1, isNot(equals(markerModel3)));
    });

    test('should maintain all properties through entity conversion', () {
      // Arrange
      final now = DateTime.now();
      final originalMarker = Marker(
        id: 'marker123',
        markerSetId: 'set456',
        label: 'Chorus',
        positionMs: 60000,
        order: 3,
        createdAt: now,
      );

      // Act
      final markerModel = MarkerModel.fromEntity(originalMarker);
      final convertedMarker = markerModel.toEntity();

      // Assert
      expect(convertedMarker, equals(originalMarker));
    });
  });
}
