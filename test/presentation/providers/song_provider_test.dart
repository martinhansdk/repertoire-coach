import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/repositories/song_repository.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/providers/song_provider.dart';

import '../../helpers/test_database.dart';
import 'song_provider_test.mocks.dart';

@GenerateMocks([SongRepository])
void main() {
  group('Song Providers', () {
    test('localSongDataSourceProvider returns LocalSongDataSource', () {
      final testDb = createTestDatabase();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
      );

      expect(container.read(localSongDataSourceProvider),
          isA<LocalSongDataSource>());

      container.dispose();
      testDb.close();
    });

    test('songRepositoryProvider returns SongRepository', () {
      final testDb = createTestDatabase();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
      );

      expect(
          container.read(songRepositoryProvider), isA<SongRepository>());

      container.dispose();
      testDb.close();
    }, skip: 'Requires Supabase initialization');

    group('songsByConcertProvider', () {
      test('returns a list of songs on success', () async {
        final mockRepository = MockSongRepository();
        final songs = [
          Song(id: 's1', concertId: 'c1', title: 'Song 1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        updatedAt: DateTime(2024, 1, 1),
        ];
        when(mockRepository.getSongsByConcert('c1'))
            .thenAnswer((_) async => songs);

        final container = ProviderContainer(
          overrides: [
            songRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(songsByConcertProvider('c1').future);
        expect(result, songs);
      });

      test('returns an empty list on error', () async {
        final mockRepository = MockSongRepository();
        when(mockRepository.getSongsByConcert('c1')).thenThrow(Exception('test error'));

        final container = ProviderContainer(
          overrides: [
            songRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(songsByConcertProvider('c1').future);
        expect(result, []);
      });
    });

    group('songByIdProvider', () {
      test('returns a song on success', () async {
        final mockRepository = MockSongRepository();
        final song = Song(id: 's1', concertId: 'c1', title: 'Song 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
        updatedAt: DateTime(2024, 1, 1),
        when(mockRepository.getSongById('s1'))
            .thenAnswer((_) async => song);

        final container = ProviderContainer(
          overrides: [
            songRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(songByIdProvider('s1').future);
        expect(result, song);
      });

       test('returns null if song not found', () async {
        final mockRepository = MockSongRepository();
        when(mockRepository.getSongById('s1'))
            .thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            songRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(songByIdProvider('s1').future);
        expect(result, isNull);
      });
    });
  });
}
