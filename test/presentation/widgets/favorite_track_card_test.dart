import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/providers/song_provider.dart';
import 'package:repertoire_coach/presentation/widgets/favorite_track_card.dart';

void main() {
  group('FavoriteTrackCard', () {
    late FavoriteTrack testFavorite;
    late Song testSong;
    late Concert testConcert;
    late Choir testChoir;
    late bool tapCalled;
    late bool removeCalled;

    setUp(() {
      tapCalled = false;
      removeCalled = false;

      // Create test data
      testChoir = Choir(
        id: 'choir-1',
        name: 'City Choir',
        ownerId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      testConcert = Concert(
        id: 'concert-1',
        choirId: 'choir-1',
        choirName: 'City Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 1, 1),
      );

      testSong = Song(
        id: 'song-1',
        concertId: 'concert-1',
        title: 'Amazing Grace',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      testFavorite = FavoriteTrack(
        addedAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        track: Track(
          id: 'track-1',
          songId: 'song-1',
          name: 'Soprano',
          audioUrl: 'https://example.com/audio.mp3',
          storagePath: 'tracks/track-1.mp3',
          durationMs: 180000,
          filePath: null,
          createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ),
      );
    });

    Widget buildWidget({FavoriteTrack? favorite}) {
      final fav = favorite ?? testFavorite;
      return ProviderScope(
        overrides: [
          songByIdProvider(fav.track.songId).overrideWith((ref) async => testSong),
          concertByIdProvider(testSong.concertId).overrideWith((ref) async => testConcert),
          choirByIdProvider(testConcert.choirId).overrideWith((ref) async => testChoir),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FavoriteTrackCard(
              favorite: fav,
              onTap: () => tapCalled = true,
              onRemove: () => removeCalled = true,
            ),
          ),
        ),
      );
    }

    testWidgets('displays song title prominently', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Amazing Grace'), findsOneWidget);

      final titleWidget = tester.widget<Text>(
        find.text('Amazing Grace'),
      );
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('displays track name', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Soprano'), findsOneWidget);
    });

    testWidgets('displays choir name', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('City Choir'), findsOneWidget);
    });

    testWidgets('displays audio icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    });

    testWidgets('displays favorite icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavoriteTrackCard));
      await tester.pumpAndSettle();

      expect(tapCalled, isTrue);
    });

    testWidgets('calls onRemove when remove button is tapped', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
    });

    testWidgets('does not call onTap when remove button is tapped',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
      expect(tapCalled, isFalse);
    });

    testWidgets('truncates long song titles with ellipsis', (tester) async {
      final longTitleSong = Song(
        id: 'song-2',
        concertId: 'concert-1',
        title: 'This is a very long song title that should be truncated',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final longTitleFavorite = FavoriteTrack(
        addedAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        track: Track(
          id: 'track-2',
          songId: 'song-2',
          name: 'Soprano',
          audioUrl: null,
          storagePath: null,
          durationMs: null,
          filePath: null,
          createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songByIdProvider('song-2').overrideWith((ref) async => longTitleSong),
            concertByIdProvider('concert-1').overrideWith((ref) async => testConcert),
            choirByIdProvider('choir-1').overrideWith((ref) async => testChoir),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FavoriteTrackCard(
                favorite: longTitleFavorite,
                onTap: () {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<Text>(
        find.text('This is a very long song title that should be truncated'),
      );
      expect(titleWidget.overflow, TextOverflow.ellipsis);
      expect(titleWidget.maxLines, 1);
    });

    testWidgets('has proper tooltip on remove button', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final removeButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.icon is Icon && (widget.icon as Icon).icon == Icons.favorite,
      );

      expect(removeButton, findsOneWidget);

      final iconButton = tester.widget<IconButton>(removeButton);
      expect(iconButton.tooltip, 'Remove from favorites');
    });
  });
}
