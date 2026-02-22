import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/domain/repositories/favorite_track_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart'
    show audioPlayerRepositoryProvider;
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
import 'package:repertoire_coach/presentation/providers/favorite_track_provider.dart';

import 'favorite_track_provider_test.mocks.dart';

@GenerateMocks([FavoriteTrackRepository, AudioPlayerRepository])
void main() {
  final now = DateTime(2024, 1, 1).toUtc();

  final testTrack = Track(
    id: 't1',
    songId: 's1',
    name: 'Soprano',
    createdAt: now,
    updatedAt: now,
  );

  final testFavorite = FavoriteTrack(
    addedAt: now,
    updatedAt: now,
    track: testTrack,
  );

  // ------------------------------------------------------------------
  // Fake SupabaseService: authenticated user
  // ------------------------------------------------------------------

  _FakeSupabaseService fakeAuth([String? userId = 'u1']) =>
      _FakeSupabaseService(userId);

  // ------------------------------------------------------------------
  // Helper: container with repo + auth overrides
  // ------------------------------------------------------------------

  ProviderContainer makeContainer(
    MockFavoriteTrackRepository repo, {
    String? userId = 'u1',
  }) {
    return ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(fakeAuth(userId)),
        favoriteTrackRepositoryProvider.overrideWithValue(repo),
        // Prevent the real AudioPlayerRepositoryImpl from being created
        // (requires Flutter bindings, audio_service, path_provider plugins).
        audioPlayerRepositoryProvider
            .overrideWithValue(_FakeAudioPlayerRepository()),
      ],
    );
  }

  // ------------------------------------------------------------------
  // favoritesProvider
  // ------------------------------------------------------------------

  group('favoritesProvider', () {
    test('returns list of favorites for authenticated user', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.getFavorites('u1')).thenAnswer((_) async => [testFavorite]);

      final container = makeContainer(repo);
      final result = await container.read(favoritesProvider.future);

      expect(result, [testFavorite]);
    });

    test('returns empty list when user is not authenticated', () async {
      final repo = MockFavoriteTrackRepository();

      final container = makeContainer(repo, userId: null);
      final result = await container.read(favoritesProvider.future);

      expect(result, isEmpty);
      verifyNever(repo.getFavorites(any));
    });
  });

  // ------------------------------------------------------------------
  // isFavoriteProvider
  // ------------------------------------------------------------------

  group('isFavoriteProvider', () {
    test('returns true when track is favorited', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => true);

      final container = makeContainer(repo);
      final result = await container.read(isFavoriteProvider('t1').future);

      expect(result, isTrue);
    });

    test('returns false when track is not favorited', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => false);

      final container = makeContainer(repo);
      final result = await container.read(isFavoriteProvider('t1').future);

      expect(result, isFalse);
    });

    test('returns false when user is not authenticated', () async {
      final repo = MockFavoriteTrackRepository();

      final container = makeContainer(repo, userId: null);
      final result = await container.read(isFavoriteProvider('t1').future);

      expect(result, isFalse);
      verifyNever(repo.isFavorite(any, any));
    });
  });

  // ------------------------------------------------------------------
  // favoriteCountProvider
  // ------------------------------------------------------------------

  group('favoriteCountProvider', () {
    test('returns count for authenticated user', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.getFavoriteCount('u1')).thenAnswer((_) async => 3);

      final container = makeContainer(repo);
      final result = await container.read(favoriteCountProvider.future);

      expect(result, 3);
    });

    test('returns 0 when user is not authenticated', () async {
      final repo = MockFavoriteTrackRepository();

      final container = makeContainer(repo, userId: null);
      final result = await container.read(favoriteCountProvider.future);

      expect(result, 0);
      verifyNever(repo.getFavoriteCount(any));
    });
  });

  // ------------------------------------------------------------------
  // FavoriteTrackActions
  // ------------------------------------------------------------------

  group('FavoriteTrackActions.addFavorite', () {
    test('delegates to repository and invalidates providers', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.addFavorite('u1', 't1', 's1')).thenAnswer((_) async {});
      when(repo.getFavorites('u1')).thenAnswer((_) async => [testFavorite]);
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => true);
      when(repo.getFavoriteCount('u1')).thenAnswer((_) async => 1);

      final container = makeContainer(repo);
      // Prime the providers so we can detect invalidation
      await container.read(favoritesProvider.future);
      await container.read(isFavoriteProvider('t1').future);
      await container.read(favoriteCountProvider.future);

      final actions = container.read(favoriteTrackActionsProvider);
      await actions.addFavorite('t1', 's1');

      verify(repo.addFavorite('u1', 't1', 's1')).called(1);
    });

    test('is a no-op when user is not authenticated', () async {
      final repo = MockFavoriteTrackRepository();

      final container = makeContainer(repo, userId: null);
      final actions = container.read(favoriteTrackActionsProvider);
      await actions.addFavorite('t1', 's1');

      verifyNever(repo.addFavorite(any, any, any));
    });
  });

  group('FavoriteTrackActions.removeFavorite', () {
    test('delegates to repository', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.removeFavorite('u1', 't1')).thenAnswer((_) async {});
      when(repo.getFavorites('u1')).thenAnswer((_) async => []);
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => false);
      when(repo.getFavoriteCount('u1')).thenAnswer((_) async => 0);

      final container = makeContainer(repo);
      final actions = container.read(favoriteTrackActionsProvider);
      await actions.removeFavorite('t1');

      verify(repo.removeFavorite('u1', 't1')).called(1);
    });

    test('is a no-op when user is not authenticated', () async {
      final repo = MockFavoriteTrackRepository();

      final container = makeContainer(repo, userId: null);
      final actions = container.read(favoriteTrackActionsProvider);
      await actions.removeFavorite('t1');

      verifyNever(repo.removeFavorite(any, any));
    });
  });

  group('FavoriteTrackActions.toggleFavorite', () {
    test('calls addFavorite when track is not currently favorited', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => false);
      when(repo.addFavorite('u1', 't1', 's1')).thenAnswer((_) async {});
      when(repo.getFavorites('u1')).thenAnswer((_) async => []);
      when(repo.getFavoriteCount('u1')).thenAnswer((_) async => 1);

      final container = makeContainer(repo);
      final actions = container.read(favoriteTrackActionsProvider);
      await actions.toggleFavorite('t1', 's1');

      verify(repo.addFavorite('u1', 't1', 's1')).called(1);
      verifyNever(repo.removeFavorite(any, any));
    });

    test('calls removeFavorite when track is currently favorited', () async {
      final repo = MockFavoriteTrackRepository();
      when(repo.isFavorite('u1', 't1')).thenAnswer((_) async => true);
      when(repo.removeFavorite('u1', 't1')).thenAnswer((_) async {});
      when(repo.getFavorites('u1')).thenAnswer((_) async => []);
      when(repo.getFavoriteCount('u1')).thenAnswer((_) async => 0);

      final container = makeContainer(repo);
      final actions = container.read(favoriteTrackActionsProvider);
      await actions.toggleFavorite('t1', 's1');

      verify(repo.removeFavorite('u1', 't1')).called(1);
      verifyNever(repo.addFavorite(any, any, any));
    });
  });
}

class _FakeAudioPlayerRepository extends Fake
    implements AudioPlayerRepository {
  @override
  void notifyFavouritesChanged() {}
}

class _FakeSupabaseService extends Fake implements SupabaseService {
  final String? _userId;

  _FakeSupabaseService(this._userId);

  @override
  String? get currentUserId => _userId;

  @override
  bool get isAuthenticated => _userId != null;
}
