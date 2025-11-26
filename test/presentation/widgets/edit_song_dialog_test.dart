import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/presentation/widgets/edit_song_dialog.dart';

void main() {
  group('EditSongDialog Widget', () {
    final testSong = Song(
      id: 'song1',
      concertId: 'concert1',
      title: 'Original Title',
      createdAt: DateTime(2024, 12, 1),
      updatedAt: DateTime(2024, 12, 1),
    );

    testWidgets('should display song title in input field', (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Edit Song'), findsOneWidget);
      expect(find.text('Original Title'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('should display Save and Cancel buttons', (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should show validation error for empty title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Act - clear the title and tap Save
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Please enter a song title'), findsOneWidget);
    }, skip: true); // TODO: Fix timer infrastructure issue

    testWidgets('should show validation error for short title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Act - enter a title that's too short
      await tester.enterText(find.byType(TextFormField), 'A');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      expect(
          find.text('Song title must be at least 2 characters'), findsOneWidget);
    }, skip: true); // TODO: Fix timer infrastructure issue

    testWidgets('should accept valid song title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Act - enter a valid title
      await tester.enterText(find.byType(TextFormField), 'New Title');
      await tester.pumpAndSettle();

      // Assert - no validation error should be shown
      expect(find.text('Please enter a song title'), findsNothing);
      expect(
          find.text('Song title must be at least 2 characters'), findsNothing);
    });

    testWidgets('should display music note icon', (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('should pre-populate title from existing song',
        (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EditSongDialog(song: testSong),
            ),
          ),
        ),
      );

      // Assert
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, 'Original Title');
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
                        builder: (context) => EditSongDialog(song: testSong),
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
      expect(find.byType(EditSongDialog), findsNothing);
    }, skip: true); // TODO: Fix timer infrastructure issue
  });
}
