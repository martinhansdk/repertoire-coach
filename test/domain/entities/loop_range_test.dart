import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/loop_range.dart';

void main() {
  group('LoopRange', () {
    test('should create a valid loop range', () {
      // Arrange & Act
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
      );

      // Assert
      expect(loopRange.startPosition, const Duration(seconds: 10));
      expect(loopRange.endPosition, const Duration(seconds: 20));
      expect(loopRange.startMarkerId, isNull);
      expect(loopRange.endMarkerId, isNull);
      expect(loopRange.duration, const Duration(seconds: 10));
      expect(loopRange.isValid, isTrue);
    });

    test('should create loop range with marker IDs', () {
      // Arrange & Act
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 5),
        endPosition: const Duration(seconds: 15),
        startMarkerId: 'marker-1',
        endMarkerId: 'marker-2',
      );

      // Assert
      expect(loopRange.startMarkerId, 'marker-1');
      expect(loopRange.endMarkerId, 'marker-2');
    });

    test('should create loop range from milliseconds', () {
      // Arrange & Act
      final loopRange = LoopRange.fromMarkers(
        startPositionMs: 5000,
        endPositionMs: 15000,
        startMarkerId: 'start',
        endMarkerId: 'end',
      );

      // Assert
      expect(loopRange.startPosition, const Duration(milliseconds: 5000));
      expect(loopRange.endPosition, const Duration(milliseconds: 15000));
      expect(loopRange.startMarkerId, 'start');
      expect(loopRange.endMarkerId, 'end');
      expect(loopRange.duration, const Duration(milliseconds: 10000));
    });

    test('should throw assertion error if end is before start', () {
      // Arrange, Act & Assert
      expect(
        () => LoopRange(
          startPosition: const Duration(seconds: 20),
          endPosition: const Duration(seconds: 10),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('should throw assertion error if end equals start', () {
      // Arrange, Act & Assert
      expect(
        () => LoopRange(
          startPosition: const Duration(seconds: 10),
          endPosition: const Duration(seconds: 10),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('contains should return true for position within range', () {
      // Arrange
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
      );

      // Act & Assert
      expect(loopRange.contains(const Duration(seconds: 10)), isTrue);
      expect(loopRange.contains(const Duration(seconds: 15)), isTrue);
      expect(loopRange.contains(const Duration(seconds: 19, milliseconds: 999)),
          isTrue);
    });

    test('contains should return false for position outside range', () {
      // Arrange
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
      );

      // Act & Assert
      expect(loopRange.contains(const Duration(seconds: 9)), isFalse);
      expect(loopRange.contains(const Duration(seconds: 20)), isFalse);
      expect(loopRange.contains(const Duration(seconds: 25)), isFalse);
      expect(loopRange.contains(Duration.zero), isFalse);
    });

    test('duration should calculate correctly', () {
      // Arrange
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 5, milliseconds: 500),
        endPosition: const Duration(seconds: 12, milliseconds: 750),
      );

      // Act & Assert
      expect(loopRange.duration, const Duration(seconds: 7, milliseconds: 250));
    });

    test('isValid should return true for valid range', () {
      // Arrange
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 1),
        endPosition: const Duration(seconds: 2),
      );

      // Act & Assert
      expect(loopRange.isValid, isTrue);
    });

    test('toString should return formatted string', () {
      // Arrange
      final loopRange = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
      );

      // Act
      final result = loopRange.toString();

      // Assert
      expect(result, contains('LoopRange'));
      expect(result, contains('start: 0:00:10.000000'));
      expect(result, contains('end: 0:00:20.000000'));
      expect(result, contains('duration: 0:00:10.000000'));
    });

    test('copyWith should create new instance with updated fields', () {
      // Arrange
      final original = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
        startMarkerId: 'marker-1',
        endMarkerId: 'marker-2',
      );

      // Act
      final updated = original.copyWith(
        startPosition: const Duration(seconds: 5),
        endMarkerId: 'marker-3',
      );

      // Assert
      expect(updated.startPosition, const Duration(seconds: 5));
      expect(updated.endPosition, const Duration(seconds: 20));
      expect(updated.startMarkerId, 'marker-1');
      expect(updated.endMarkerId, 'marker-3');

      // Original should be unchanged
      expect(original.startPosition, const Duration(seconds: 10));
      expect(original.endMarkerId, 'marker-2');
    });

    test('copyWith should preserve original values when not specified', () {
      // Arrange
      final original = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
      );

      // Act
      final copy = original.copyWith();

      // Assert
      expect(copy.startPosition, original.startPosition);
      expect(copy.endPosition, original.endPosition);
      expect(copy.startMarkerId, original.startMarkerId);
      expect(copy.endMarkerId, original.endMarkerId);
    });

    test('equality should work correctly', () {
      // Arrange
      final loopRange1 = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
        startMarkerId: 'marker-1',
        endMarkerId: 'marker-2',
      );

      final loopRange2 = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 20),
        startMarkerId: 'marker-1',
        endMarkerId: 'marker-2',
      );

      final loopRange3 = LoopRange(
        startPosition: const Duration(seconds: 10),
        endPosition: const Duration(seconds: 30),
        startMarkerId: 'marker-1',
        endMarkerId: 'marker-2',
      );

      // Act & Assert
      expect(loopRange1, equals(loopRange2));
      expect(loopRange1, isNot(equals(loopRange3)));
      expect(loopRange1.hashCode, equals(loopRange2.hashCode));
    });

    test('should handle very short loop ranges', () {
      // Arrange & Act
      final loopRange = LoopRange(
        startPosition: const Duration(milliseconds: 100),
        endPosition: const Duration(milliseconds: 101),
      );

      // Assert
      expect(loopRange.isValid, isTrue);
      expect(loopRange.duration, const Duration(milliseconds: 1));
    });

    test('should handle very long loop ranges', () {
      // Arrange & Act
      final loopRange = LoopRange(
        startPosition: const Duration(minutes: 5),
        endPosition: const Duration(hours: 1),
      );

      // Assert
      expect(loopRange.isValid, isTrue);
      expect(loopRange.duration, const Duration(minutes: 55));
    });
  });
}
