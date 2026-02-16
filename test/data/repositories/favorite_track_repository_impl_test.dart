import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/data/datasources/local/local_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/models/favorite_track_model.dart';
import 'package:repertoire_coach/data/models/track_model.dart';
import 'package:repertoire_coach/data/repositories/favorite_track_repository_impl.dart';

@GenerateMocks([
  LocalFavoriteTrackDataSource,
  LocalTrackDataSource,
  RemoteFavoriteTrackDataSource,
  SupabaseService,
])
import 'favorite_track_repository_impl_test.mocks.dart';

void main() {
  group('FavoriteTrackRepositoryImpl', () {
    late MockLocalFavoriteTrackDataSource mockLocalFavDataSource;
    late MockLocalTrackDataSource mockLocalTrackDataSource;
    late MockRemoteFavoriteTrackDataSource mockRemoteDataSource;
    late MockSupabaseService mockSupabaseService;
    late FavoriteTrackRepositoryImpl repository;

    final now = DateTime.now();
    final testTrackModel = TrackModel(
      id: 'track-1',
      songId: 'song-1',
      name: 'Test Track',
      audioUrl: 'https://example.com/audio.mp3',
      storagePath: '/tracks/audio.mp3',
      durationMs: 180000,
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      mockLocalFavDataSource = MockLocalFavoriteTrackDataSource();
      mockLocalTrackDataSource = MockLocalTrackDataSource();
      mockRemoteDataSource = MockRemoteFavoriteTrackDataSource();
      mockSupabaseService = MockSupabaseService();

      repository = FavoriteTrackRepositoryImpl(
        mockLocalFavDataSource,
        mockLocalTrackDataSource,
        mockRemoteDataSource,
        mockSupabaseService,
      );
    });

    group('addFavorite (mobile)', () {
      // Note: These tests run in the test environment where kIsWeb = false,
      // so the mobile code path is exercised.

      test('should fetch track and save to local database', () async {
        // Regression: addFavorite threw UnimplementedError on mobile/Android.
        when(mockLocalTrackDataSource.getTrackById('track-1'))
            .thenAnswer((_) async => testTrackModel);
        when(mockLocalFavDataSource.addFavorite(
          any,
          any,
          markForSync: anyNamed('markForSync'),
        )).thenAnswer((_) async {});
        when(mockSupabaseService.isAuthenticated).thenReturn(false);

        await repository.addFavorite('user-1', 'track-1', 'song-1');

        verify(mockLocalTrackDataSource.getTrackById('track-1')).called(1);
        final captured = verify(mockLocalFavDataSource.addFavorite(
          'user-1',
          captureAny,
          markForSync: true,
        )).captured;
        expect(captured.length, 1);
        final savedFavorite = captured[0] as FavoriteTrackModel;
        expect(savedFavorite.track.id, 'track-1');
        expect(savedFavorite.track.songId, 'song-1');
      });

      test('should also sync to remote when authenticated', () async {
        when(mockLocalTrackDataSource.getTrackById('track-1'))
            .thenAnswer((_) async => testTrackModel);
        when(mockLocalFavDataSource.addFavorite(
          any,
          any,
          markForSync: anyNamed('markForSync'),
        )).thenAnswer((_) async {});
        when(mockSupabaseService.isAuthenticated).thenReturn(true);
        when(mockRemoteDataSource.addFavorite(any, any, any))
            .thenAnswer((_) async {});

        await repository.addFavorite('user-1', 'track-1', 'song-1');

        verify(mockRemoteDataSource.addFavorite('user-1', 'track-1', 'song-1'))
            .called(1);
      });

      test('should not throw when track is not found locally', () async {
        when(mockLocalTrackDataSource.getTrackById('missing'))
            .thenAnswer((_) async => null);

        // Should not throw - just silently return
        await repository.addFavorite('user-1', 'missing', 'song-1');

        verifyNever(mockLocalFavDataSource.addFavorite(
          any,
          any,
          markForSync: anyNamed('markForSync'),
        ));
      });
    });
  });
}
