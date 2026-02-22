import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/domain/repositories/marker_repository.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';

import 'marker_provider_test.mocks.dart';

@GenerateMocks([MarkerRepository])
void main() {
  final now = DateTime(2024, 1, 1).toUtc();

  final testMarkerSet = MarkerSet(
    id: 'ms1',
    trackId: 't1',
    name: 'Verse',
    isShared: false,
    isTimeSynced: true,
    createdByUserId: 'u1',
    createdAt: now,
    updatedAt: now,
  );

  final testMarker = Marker(
    id: 'ms1:0',
    markerSetId: 'ms1',
    label: 'Intro',
    positionMs: 1000,
    order: 0,
    createdAt: now,
    updatedAt: now,
  );

  ProviderContainer makeContainer(MockMarkerRepository repo) {
    return ProviderContainer(
      overrides: [
        markerRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  // ------------------------------------------------------------------
  // markerSetsByTrackProvider
  // ------------------------------------------------------------------

  group('markerSetsByTrackProvider', () {
    test('returns marker sets for a track', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerSetsByTrack('t1', userId: 'u1'))
          .thenAnswer((_) async => [testMarkerSet]);

      final container = makeContainer(repo);
      final result = await container
          .read(markerSetsByTrackProvider(('t1', 'u1')).future);

      expect(result, [testMarkerSet]);
    });

    test('returns empty list when no sets exist', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerSetsByTrack('t1', userId: null))
          .thenAnswer((_) async => []);

      final container = makeContainer(repo);
      final result = await container
          .read(markerSetsByTrackProvider(('t1', null)).future);

      expect(result, isEmpty);
    });

    test('returns empty list on exception (web fallback)', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerSetsByTrack('t1', userId: 'u1'))
          .thenThrow(Exception('db unavailable'));

      final container = makeContainer(repo);
      final result = await container
          .read(markerSetsByTrackProvider(('t1', 'u1')).future);

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // markerSetByIdProvider
  // ------------------------------------------------------------------

  group('markerSetByIdProvider', () {
    test('returns the marker set when found', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerSetById('ms1'))
          .thenAnswer((_) async => testMarkerSet);

      final container = makeContainer(repo);
      final result =
          await container.read(markerSetByIdProvider('ms1').future);

      expect(result, testMarkerSet);
    });

    test('returns null when not found', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerSetById('missing')).thenAnswer((_) async => null);

      final container = makeContainer(repo);
      final result =
          await container.read(markerSetByIdProvider('missing').future);

      expect(result, isNull);
    });
  });

  // ------------------------------------------------------------------
  // markersByMarkerSetProvider
  // ------------------------------------------------------------------

  group('markersByMarkerSetProvider', () {
    test('returns markers for a marker set', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkersByMarkerSet('ms1'))
          .thenAnswer((_) async => [testMarker]);

      final container = makeContainer(repo);
      final result =
          await container.read(markersByMarkerSetProvider('ms1').future);

      expect(result, [testMarker]);
    });

    test('returns empty list on exception (web fallback)', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkersByMarkerSet('ms1'))
          .thenThrow(Exception('db unavailable'));

      final container = makeContainer(repo);
      final result =
          await container.read(markersByMarkerSetProvider('ms1').future);

      expect(result, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // markerByIdProvider
  // ------------------------------------------------------------------

  group('markerByIdProvider', () {
    test('returns the marker when found', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerById('ms1:0')).thenAnswer((_) async => testMarker);

      final container = makeContainer(repo);
      final result =
          await container.read(markerByIdProvider('ms1:0').future);

      expect(result, testMarker);
    });

    test('returns null when not found', () async {
      final repo = MockMarkerRepository();
      when(repo.getMarkerById('missing')).thenAnswer((_) async => null);

      final container = makeContainer(repo);
      final result =
          await container.read(markerByIdProvider('missing').future);

      expect(result, isNull);
    });
  });
}
