import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/presentation/providers/song_provider.dart';
import 'package:repertoire_coach/presentation/screens/song_list_screen.dart';
import 'package:repertoire_coach/presentation/widgets/song_card.dart';

void main() {
  group('SongListScreen Widget', () {
    final mockSongs = [
      Song(
        id: '1',
        concertId: 'concert1',
        title: 'Ave Verum Corpus',
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 1),
      ),
      Song(
        id: '2',
        concertId: 'concert1',
        title: 'Lux Aurumque',
        createdAt: DateTime(2024, 12, 2),
        updatedAt: DateTime(2024, 12, 2),
      ),
      Song(
        id: '3',
        concertId: 'concert1',
        title: 'The Seal Lullaby',
        createdAt: DateTime(2024, 12, 3),
        updatedAt: DateTime(2024, 12, 3),
      ),
    ];

    testWidgets('should display concert name in app bar', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => mockSongs),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Spring Concert'), findsOneWidget);
    });

    testWidgets('should display list of songs', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => mockSongs),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(SongCard), findsNWidgets(3));
      expect(find.text('Ave Verum Corpus'), findsOneWidget);
      expect(find.text('Lux Aurumque'), findsOneWidget);
      expect(find.text('The Seal Lullaby'), findsOneWidget);
    });

    testWidgets('should display floating action button', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => mockSongs),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Song'), findsOneWidget);
    });

    testWidgets('should display empty state when no songs', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => []),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Songs Yet'), findsOneWidget);
      expect(find.text('Add your first song to this concert'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_outlined), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async {
              // Simulate slow loading
              await Future.delayed(const Duration(milliseconds: 100));
              return mockSongs;
            }),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Before pumpAndSettle, should show loading
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for loading to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should display error state on error', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async {
              throw Exception('Database error');
            }),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to fail
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error Loading Songs'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should show create song dialog when FAB is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => mockSongs),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Act - tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add New Song'), findsOneWidget);
    }, skip: true); // TODO: Fix timer infrastructure issue

    testWidgets('should show create song dialog from empty state button',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsByConcertProvider('concert1').overrideWith((arg) async => []),
          ],
          child: const MaterialApp(
            home: SongListScreen(
              concertId: 'concert1',
              concertName: 'Spring Concert',
            ),
          ),
        ),
      );

      // Wait for async data to load
      await tester.pumpAndSettle();

      // Act - tap the "Add Song" button in empty state
      await tester.tap(find.text('Add Song').first);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add New Song'), findsOneWidget);
    }, skip: true); // TODO: Fix timer infrastructure issue
  });
}
