import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/widgets/create_song_dialog.dart';

void main() {
  group('CreateSongDialog Widget', () {
    testWidgets('should display concert name and input field', (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Add New Song'), findsOneWidget);
      expect(find.text('Concert: Spring Concert'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Song Title'), findsOneWidget);
    });

    testWidgets('should display Add and Cancel buttons', (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('should show validation error for empty title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Act - tap Add button without entering title
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Please enter a song title'), findsOneWidget);
    });

    testWidgets('should show validation error for short title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Act - enter a title that's too short
      await tester.enterText(find.byType(TextFormField), 'A');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Assert
      expect(
          find.text('Song title must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('should accept valid song title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Act - enter a valid title
      await tester.enterText(find.byType(TextFormField), 'Ave Verum Corpus');
      await tester.pumpAndSettle();

      // Assert - no validation error should be shown
      expect(find.text('Please enter a song title'), findsNothing);
      expect(
          find.text('Song title must be at least 2 characters'), findsNothing);
    });

    testWidgets('should display music note icon', (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateSongDialog(
                concertId: 'concert1',
                concertName: 'Spring Concert',
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('should close dialog when Cancel is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => const CreateSongDialog(
                          concertId: 'concert1',
                          concertName: 'Spring Concert',
                        ),
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Act - open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CreateSongDialog), findsNothing);
    });
  });
}
