import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/data/datasources/local/local_track_data_source.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/repositories/track_repository.dart';
import 'package:repertoire_coach/presentation/providers/track_provider.dart';

import 'track_provider_test.mocks.dart';

@GenerateMocks([TrackRepository])
void main() {
  group('Track Providers', () {
    test('localTrackDataSourceProvider returns LocalTrackDataSource', () {
      final container = ProviderContainer();
      expect(container.read(localTrackDataSourceProvider),
          isA<LocalTrackDataSource>());
    });

    test('trackRepositoryProvider returns TrackRepository', () {
      final container = ProviderContainer();
      expect(
          container.read(trackRepositoryProvider), isA<TrackRepository>());
    });

    group('tracksBySongProvider', () {
      test('returns a list of tracks on success', () async {
        final mockRepository = MockTrackRepository();
        final tracks = [
          Track(id: 't1', songId: 's1', name: 'Track 1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        ];
        when(mockRepository.getTracksBySong('s1'))
            .thenAnswer((_) async => tracks);

        final container = ProviderContainer(
          overrides: [
            trackRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(tracksBySongProvider('s1').future);
        expect(result, tracks);
      });

      test('returns an empty list on error', () async {
        final mockRepository = MockTrackRepository();
        when(mockRepository.getTracksBySong('s1')).thenThrow(Exception('test error'));

        final container = ProviderContainer(
          overrides: [
            trackRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(tracksBySongProvider('s1').future);
        expect(result, []);
      });
    });

    group('trackByIdProvider', () {
      test('returns a track on success', () async {
        final mockRepository = MockTrackRepository();
        final track = Track(id: 't1', songId: 's1', name: 'Track 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
        when(mockRepository.getTrackById('t1'))
            .thenAnswer((_) async => track);

        final container = ProviderContainer(
          overrides: [
            trackRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(trackByIdProvider('t1').future);
        expect(result, track);
      });

       test('returns null if track not found', () async {
        final mockRepository = MockTrackRepository();
        when(mockRepository.getTrackById('t1'))
            .thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            trackRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(trackByIdProvider('t1').future);
        expect(result, isNull);
      });
    });
  });
}
