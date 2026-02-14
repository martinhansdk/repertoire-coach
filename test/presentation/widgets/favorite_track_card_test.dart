import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/favorite_track.dart';
import 'package:repertoire_coach/presentation/widgets/favorite_track_card.dart';

void main() {
  group('FavoriteTrackCard', () {
    late FavoriteTrack testFavorite;
    late bool tapCalled;
    late bool removeCalled;

    setUp(() {
      tapCalled = false;
      removeCalled = false;

      testFavorite = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: DateTime(2024, 1, 15),
        trackName: 'Soprano',
        songTitle: 'Amazing Grace',
        choirName: 'City Choir',
        audioUrl: 'https://example.com/audio.mp3',
        durationMs: 180000,
      );
    });

    Widget buildWidget() {
      return MaterialApp(
        home: Scaffold(
          body: FavoriteTrackCard(
            favorite: testFavorite,
            onTap: () => tapCalled = true,
            onRemove: () => removeCalled = true,
          ),
        ),
      );
    }

    testWidgets('displays song title prominently', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('Amazing Grace'), findsOneWidget);

      final titleWidget = tester.widget<Text>(
        find.text('Amazing Grace'),
      );
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('displays track name', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('Soprano'), findsOneWidget);
    });

    testWidgets('displays choir name', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.text('City Choir'), findsOneWidget);
    });

    testWidgets('displays audio icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    });

    testWidgets('displays favorite icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('calls onTap when card is tapped', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byType(FavoriteTrackCard));
      await tester.pumpAndSettle();

      expect(tapCalled, isTrue);
    });

    testWidgets('calls onRemove when remove button is tapped', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
    });

    testWidgets('does not call onTap when remove button is tapped',
        (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
      expect(tapCalled, isFalse);
    });

    testWidgets('truncates long song titles with ellipsis', (tester) async {
      final longTitleFavorite = FavoriteTrack(
        userId: 'user-1',
        trackId: 'track-1',
        songId: 'song-1',
        addedAt: DateTime(2024, 1, 15),
        trackName: 'Soprano',
        songTitle: 'This is a very long song title that should be truncated',
        choirName: 'City Choir',
        audioUrl: null,
        durationMs: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FavoriteTrackCard(
              favorite: longTitleFavorite,
              onTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(
        find.text('This is a very long song title that should be truncated'),
      );
      expect(titleWidget.overflow, TextOverflow.ellipsis);
      expect(titleWidget.maxLines, 1);
    });

    testWidgets('has proper tooltip on remove button', (tester) async {
      await tester.pumpWidget(buildWidget());

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
