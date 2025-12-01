import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/presentation/widgets/song_card.dart';

void main() {
  group('SongCard Widget', () {
    testWidgets('should display song information correctly', (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Ave Verum Corpus',
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 1),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Assert
      expect(find.text('Ave Verum Corpus'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('should handle onTap callback', (tester) async {
      // Arrange
      bool tapped = false;
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Test Song',
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 1),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(
              song: song,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SongCard));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, isTrue);
    });

    testWidgets('should display popup menu button', (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Test Song',
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 1),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Assert
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('should show edit and delete menu items when menu is tapped',
        (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Test Song',
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 1),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Tap the menu button
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('should format recent creation dates correctly',
        (tester) async {
      // Arrange - song created today
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Recent Song',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('Created today'), findsOneWidget);
    });

    testWidgets('should format yesterday date correctly', (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Yesterday Song',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('Created yesterday'), findsOneWidget);
    });

    testWidgets('should format days ago correctly', (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'Old Song',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongCard(song: song),
          ),
        ),
      );

      // Assert
      expect(find.textContaining('Created 5 days ago'), findsOneWidget);
    });

    testWidgets('should handle long song titles with ellipsis', (tester) async {
      // Arrange
      final song = Song(
        id: '1',
        concertId: 'concert1',
        title: 'This Is A Very Long Song Title That Should Be Truncated',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300, // Constrained width to force ellipsis
              child: SongCard(song: song),
            ),
          ),
        ),
      );

      // Assert - just verify it renders without error
      expect(find.byType(SongCard), findsOneWidget);
    });
  });
}
