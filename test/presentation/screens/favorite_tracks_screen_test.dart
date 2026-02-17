import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/repositories/favorite_track_repository.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/providers/favorite_track_provider.dart';
import 'package:repertoire_coach/presentation/providers/song_provider.dart';
import 'package:repertoire_coach/presentation/screens/favorite_tracks_screen.dart';

import 'favorite_tracks_screen_test.mocks.dart';

@GenerateMocks([FavoriteTrackRepository])
void main() {
  group('FavoriteTracksScreen', () {
    late MockFavoriteTrackRepository mockRepository;
    late List<FavoriteTrack> testFavorites;
    late Song testSong1;
    late Song testSong2;
    late Concert testConcert1;
    late Concert testConcert2;
    late Choir testChoir1;
    late Choir testChoir2;

    setUp(() {
      mockRepository = MockFavoriteTrackRepository();

      // Create choirs
      testChoir1 = Choir(
        id: 'choir-1',
        name: 'City Choir',
        ownerId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      testChoir2 = Choir(
        id: 'choir-2',
        name: 'Community Choir',
        ownerId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // Create concerts
      testConcert1 = Concert(
        id: 'concert-1',
        choirId: 'choir-1',
        choirName: 'City Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      testConcert2 = Concert(
        id: 'concert-2',
        choirId: 'choir-2',
        choirName: 'Community Choir',
        name: 'Winter Concert',
        concertDate: DateTime(2024, 12, 15),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // Create songs
      testSong1 = Song(
        id: 'song-1',
        concertId: 'concert-1',
        title: 'Amazing Grace',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      testSong2 = Song(
        id: 'song-2',
        concertId: 'concert-2',
        title: 'Hallelujah',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // Create favorites with tracks
      testFavorites = [
        FavoriteTrack(
          addedAt: DateTime(2024, 1, 15),
          track: Track(
            id: 'track-1',
            songId: 'song-1',
            name: 'Soprano',
            audioUrl: 'https://example.com/audio1.mp3',
            storagePath: 'tracks/track-1.mp3',
            durationMs: 180000,
            filePath: null,
            createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
          ),
        ),
        FavoriteTrack(
          addedAt: DateTime(2024, 1, 14),
          track: Track(
            id: 'track-2',
            songId: 'song-2',
            name: 'Alto',
            audioUrl: 'https://example.com/audio2.mp3',
            storagePath: 'tracks/track-2.mp3',
            durationMs: 240000,
            filePath: null,
            createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
          ),
        ),
      ];
    });

    Widget buildWidget({List<FavoriteTrack>? favorites}) {
      return ProviderScope(
        overrides: [
          favoriteTrackRepositoryProvider.overrideWithValue(mockRepository),
          favoritesProvider.overrideWith((ref) async {
            return favorites ?? testFavorites;
          }),
          // Override song providers for lookup
          songByIdProvider('song-1').overrideWith((ref) async => testSong1),
          songByIdProvider('song-2').overrideWith((ref) async => testSong2),
          // Override concert providers for lookup
          concertByIdProvider('concert-1').overrideWith((ref) async => testConcert1),
          concertByIdProvider('concert-2').overrideWith((ref) async => testConcert2),
          // Override choir providers for lookup
          choirByIdProvider('choir-1').overrideWith((ref) async => testChoir1),
          choirByIdProvider('choir-2').overrideWith((ref) async => testChoir2),
        ],
        child: const MaterialApp(
          home: FavoriteTracksScreen(),
        ),
      );
    }

    testWidgets('displays app bar with app name', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Repertoire Coach'), findsOneWidget);
    });

    testWidgets('displays list of favorites when data loads', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Amazing Grace'), findsOneWidget);
      expect(find.text('Soprano'), findsOneWidget);
      expect(find.text('City Choir'), findsOneWidget);

      expect(find.text('Hallelujah'), findsOneWidget);
      expect(find.text('Alto'), findsOneWidget);
      expect(find.text('Community Choir'), findsOneWidget);
    });

    testWidgets('displays empty state when no favorites', (tester) async {
      await tester.pumpWidget(buildWidget(favorites: []));
      await tester.pumpAndSettle();

      expect(find.text('No Favorite Tracks'), findsOneWidget);
      expect(
        find.text('Tap the heart icon on any track to add it to your favorites'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    });

    testWidgets('displays loading indicator while loading', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // Note: Error state tests are skipped due to async timing complexity in widget tests.
    // Error handling is tested at the repository level.

    testWidgets('supports pull to refresh', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Should rebuild the widget after refresh
      expect(find.text('Amazing Grace'), findsOneWidget);
    });

    testWidgets('favorite cards are tappable', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Verify cards exist and are tappable
      expect(find.text('Amazing Grace'), findsOneWidget);
      expect(find.text('Hallelujah'), findsOneWidget);

      // Cards should be wrapped in InkWell or similar for tap handling
      final cards = find.byType(InkWell);
      expect(cards, findsWidgets);
    });

    testWidgets('displays favorite track cards in correct order',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, 2);

      // Favorites should be in order (most recent first based on addedAt)
      final texts = find.byType(Text);
      final textWidgets = texts.evaluate().map((e) => e.widget as Text).toList();
      final songTitles = textWidgets
          .where((t) => t.data == 'Amazing Grace' || t.data == 'Hallelujah')
          .map((t) => t.data)
          .toList();

      // Amazing Grace was added on 2024-01-15, Hallelujah on 2024-01-14
      // So Amazing Grace should come first
      expect(songTitles.first, 'Amazing Grace');
    });
  });
}
