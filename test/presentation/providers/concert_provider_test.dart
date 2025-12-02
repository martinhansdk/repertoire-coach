import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/repositories/concert_repository.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';

import 'concert_provider_test.mocks.dart';

@GenerateMocks([ConcertRepository])
void main() {
  group('Concert Providers', () {
    test('databaseProvider returns AppDatabase', () {
      final container = ProviderContainer();
      expect(container.read(databaseProvider), isA<db.AppDatabase>());
    });

    test('localConcertDataSourceProvider returns LocalConcertDataSource', () {
      final container = ProviderContainer();
      expect(container.read(localConcertDataSourceProvider),
          isA<LocalConcertDataSource>());
    });

    test('concertRepositoryProvider returns ConcertRepository', () {
      final container = ProviderContainer();
      expect(
          container.read(concertRepositoryProvider), isA<ConcertRepository>());
    });

    group('concertsProvider', () {
      test('returns a list of concerts on success', () async {
        final mockRepository = MockConcertRepository();
        final concerts = [
          Concert(id: 'c1', name: 'Concert 1', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now()),
        ];
        when(mockRepository.getConcerts()).thenAnswer((_) async => concerts);

        final container = ProviderContainer(
          overrides: [
            concertRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(concertsProvider.future);
        expect(result, concerts);
      });

      test('returns an empty list on error', () async {
        final mockRepository = MockConcertRepository();
        when(mockRepository.getConcerts()).thenThrow(Exception('test error'));

        final container = ProviderContainer(
          overrides: [
            concertRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(concertsProvider.future);
        expect(result, []);
      });
    });

    group('concertsByChoirProvider', () {
      test('returns filtered concerts on success', () async {
        final mockRepository = MockConcertRepository();
        final concerts = [
          Concert(id: 'c1', name: 'Concert 1', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now()),
        ];
        when(mockRepository.getConcertsByChoir('choir1'))
            .thenAnswer((_) async => concerts);

        final container = ProviderContainer(
          overrides: [
            concertRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result =
            await container.read(concertsByChoirProvider('choir1').future);
        expect(result, concerts);
      });
    });

    group('concertByIdProvider', () {
      test('returns a concert on success', () async {
        final mockRepository = MockConcertRepository();
        final concert = Concert(id: 'c1', name: 'Concert 1', choirId: 'choir1', choirName: 'Choir', concertDate: DateTime.now(), createdAt: DateTime.now());
        when(mockRepository.getConcertById('c1'))
            .thenAnswer((_) async => concert);

        final container = ProviderContainer(
          overrides: [
            concertRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(concertByIdProvider('c1').future);
        expect(result, concert);
      });

       test('returns null if concert not found', () async {
        final mockRepository = MockConcertRepository();
        when(mockRepository.getConcertById('c1'))
            .thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            concertRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(concertByIdProvider('c1').future);
        expect(result, isNull);
      });
    });
  });
}
