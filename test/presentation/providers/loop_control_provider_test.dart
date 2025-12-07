import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/loop_range.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/loop_control_provider.dart';

import 'loop_control_provider_test.mocks.dart';

@GenerateMocks([AudioPlayerRepository])
void main() {
  group('LoopControls', () {
    late MockAudioPlayerRepository mockRepository;
    late ProviderContainer container;
    late LoopControls controls;

    setUp(() {
      mockRepository = MockAudioPlayerRepository();
      container = ProviderContainer(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      controls = container.read(loopControlsProvider);
    });

    tearDown(() {
      container.dispose();
    });

    group('setLoopFromMarkers', () {
      test('sets loop range with both marker IDs', () async {
        // Arrange
        final startMarker = Marker(
          id: 'marker-1',
          markerSetId: 'set-1',
          label: 'Start',
          positionMs: 10000,
          order: 0,
          createdAt: DateTime.now(),
        );

        final endMarker = Marker(
          id: 'marker-2',
          markerSetId: 'set-1',
          label: 'End',
          positionMs: 20000,
          order: 1,
          createdAt: DateTime.now(),
        );

        // Act
        await controls.setLoopFromMarkers(startMarker, endMarker);

        // Assert
        final captured = verify(mockRepository.setLoopRange(captureAny)).captured.single as LoopRange;
        expect(captured.startPosition, const Duration(milliseconds: 10000));
        expect(captured.endPosition, const Duration(milliseconds: 20000));
        expect(captured.startMarkerId, 'marker-1');
        expect(captured.endMarkerId, 'marker-2');
      });

      test('throws ArgumentError if end marker is before start marker', () async {
        // Arrange
        final startMarker = Marker(
          id: 'marker-1',
          markerSetId: 'set-1',
          label: 'Start',
          positionMs: 20000,
          order: 0,
          createdAt: DateTime.now(),
        );

        final endMarker = Marker(
          id: 'marker-2',
          markerSetId: 'set-1',
          label: 'End',
          positionMs: 10000,
          order: 1,
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => controls.setLoopFromMarkers(startMarker, endMarker),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });

      test('throws ArgumentError if markers have same position', () async {
        // Arrange
        final startMarker = Marker(
          id: 'marker-1',
          markerSetId: 'set-1',
          label: 'Start',
          positionMs: 15000,
          order: 0,
          createdAt: DateTime.now(),
        );

        final endMarker = Marker(
          id: 'marker-2',
          markerSetId: 'set-1',
          label: 'End',
          positionMs: 15000,
          order: 1,
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => controls.setLoopFromMarkers(startMarker, endMarker),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });
    });

    group('setLoopFromMarkerToPosition', () {
      test('sets loop range with marker as start', () async {
        // Arrange
        final marker = Marker(
          id: 'marker-1',
          markerSetId: 'set-1',
          label: 'Start',
          positionMs: 10000,
          order: 0,
          createdAt: DateTime.now(),
        );
        final customPosition = const Duration(milliseconds: 25000);

        // Act
        await controls.setLoopFromMarkerToPosition(
          marker: marker,
          customPosition: customPosition,
          markerIsStart: true,
        );

        // Assert
        final captured = verify(mockRepository.setLoopRange(captureAny)).captured.single as LoopRange;
        expect(captured.startPosition, const Duration(milliseconds: 10000));
        expect(captured.endPosition, const Duration(milliseconds: 25000));
        expect(captured.startMarkerId, 'marker-1');
        expect(captured.endMarkerId, isNull);
      });

      test('sets loop range with marker as end', () async {
        // Arrange
        final marker = Marker(
          id: 'marker-2',
          markerSetId: 'set-1',
          label: 'End',
          positionMs: 30000,
          order: 1,
          createdAt: DateTime.now(),
        );
        final customPosition = const Duration(milliseconds: 5000);

        // Act
        await controls.setLoopFromMarkerToPosition(
          marker: marker,
          customPosition: customPosition,
          markerIsStart: false,
        );

        // Assert
        final captured = verify(mockRepository.setLoopRange(captureAny)).captured.single as LoopRange;
        expect(captured.startPosition, const Duration(milliseconds: 5000));
        expect(captured.endPosition, const Duration(milliseconds: 30000));
        expect(captured.startMarkerId, isNull);
        expect(captured.endMarkerId, 'marker-2');
      });

      test('throws ArgumentError if custom position creates invalid range (marker is start)', () async {
        // Arrange
        final marker = Marker(
          id: 'marker-1',
          markerSetId: 'set-1',
          label: 'Start',
          positionMs: 20000,
          order: 0,
          createdAt: DateTime.now(),
        );
        final customPosition = const Duration(milliseconds: 10000);

        // Act & Assert
        expect(
          () => controls.setLoopFromMarkerToPosition(
            marker: marker,
            customPosition: customPosition,
            markerIsStart: true,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });

      test('throws ArgumentError if custom position creates invalid range (marker is end)', () async {
        // Arrange
        final marker = Marker(
          id: 'marker-2',
          markerSetId: 'set-1',
          label: 'End',
          positionMs: 10000,
          order: 1,
          createdAt: DateTime.now(),
        );
        final customPosition = const Duration(milliseconds: 20000);

        // Act & Assert
        expect(
          () => controls.setLoopFromMarkerToPosition(
            marker: marker,
            customPosition: customPosition,
            markerIsStart: false,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });
    });

    group('setCustomLoop', () {
      test('sets loop range without marker IDs', () async {
        // Arrange
        const startPosition = Duration(milliseconds: 15000);
        const endPosition = Duration(milliseconds: 35000);

        // Act
        await controls.setCustomLoop(
          startPosition: startPosition,
          endPosition: endPosition,
        );

        // Assert
        final captured = verify(mockRepository.setLoopRange(captureAny)).captured.single as LoopRange;
        expect(captured.startPosition, startPosition);
        expect(captured.endPosition, endPosition);
        expect(captured.startMarkerId, isNull);
        expect(captured.endMarkerId, isNull);
      });

      test('throws ArgumentError if end is before start', () async {
        // Arrange
        const startPosition = Duration(milliseconds: 30000);
        const endPosition = Duration(milliseconds: 10000);

        // Act & Assert
        expect(
          () => controls.setCustomLoop(
            startPosition: startPosition,
            endPosition: endPosition,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });

      test('throws ArgumentError if end equals start', () async {
        // Arrange
        const position = Duration(milliseconds: 15000);

        // Act & Assert
        expect(
          () => controls.setCustomLoop(
            startPosition: position,
            endPosition: position,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(mockRepository.setLoopRange(any));
      });
    });

    group('clearLoop', () {
      test('calls repository with null', () async {
        // Act
        await controls.clearLoop();

        // Assert
        verify(mockRepository.setLoopRange(null)).called(1);
      });
    });

    group('currentLoopRange', () {
      test('returns current loop range from repository', () {
        // Arrange
        final loopRange = LoopRange(
          startPosition: const Duration(seconds: 10),
          endPosition: const Duration(seconds: 20),
        );
        when(mockRepository.currentLoopRange).thenReturn(loopRange);

        // Act
        final result = controls.currentLoopRange;

        // Assert
        expect(result, loopRange);
        verify(mockRepository.currentLoopRange).called(1);
      });

      test('returns null if no loop range is active', () {
        // Arrange
        when(mockRepository.currentLoopRange).thenReturn(null);

        // Act
        final result = controls.currentLoopRange;

        // Assert
        expect(result, isNull);
        verify(mockRepository.currentLoopRange).called(1);
      });
    });

    group('isLooping', () {
      test('returns true when range looping is active', () {
        // Arrange
        when(mockRepository.isRangeLooping).thenReturn(true);

        // Act
        final result = controls.isLooping;

        // Assert
        expect(result, isTrue);
        verify(mockRepository.isRangeLooping).called(1);
      });

      test('returns false when range looping is not active', () {
        // Arrange
        when(mockRepository.isRangeLooping).thenReturn(false);

        // Act
        final result = controls.isLooping;

        // Assert
        expect(result, isFalse);
        verify(mockRepository.isRangeLooping).called(1);
      });
    });

    test('loopControlsProvider returns LoopControls instance', () {
      expect(controls, isA<LoopControls>());
    });
  });
}
