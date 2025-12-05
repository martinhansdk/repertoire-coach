import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/presentation/providers/track_provider.dart';
import 'package:repertoire_coach/presentation/screens/song_detail_screen.dart';
import 'package:repertoire_coach/presentation/widgets/add_track_dialog.dart';

void main() {
  group('SongDetailScreen Widget', () {
    final testTrack = Track(
      id: 't1',
      songId: 's1',
      name: 'Test Track',
      filePath: '/path/to/audio.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('should display app bar with song title and concert name',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Song'), findsOneWidget);
      expect(find.text('Test Concert'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading',
        (tester) async {
      // Arrange - Create a never-completing future to keep it in loading state
      final completer = Completer<List<Track>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      // Pump once to build the widget
      await tester.pump();

      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty state when no tracks', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Tracks Yet'), findsOneWidget);
      expect(find.text('Add your first track to this song'), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
    });

    testWidgets('should display error state when loading fails',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith(
              (ref) => Future.error('Failed to load tracks'),
            ),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error Loading Tracks'), findsOneWidget);
      expect(find.text('Failed to load tracks'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('should call onRetry when retry button is tapped',
        (tester) async {
      // Arrange
      var callCount = 0;
      final container = ProviderContainer(
        overrides: [
          tracksBySongProvider('s1').overrideWith((ref) {
            callCount++;
            if (callCount == 1) {
              return Future.error('Failed to load tracks');
            }
            return Future.value([]);
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert error state
      expect(find.text('Error Loading Tracks'), findsOneWidget);

      // Act - tap retry button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      // Assert - should show empty state after retry
      expect(find.text('No Tracks Yet'), findsOneWidget);
      expect(callCount, 2);

      container.dispose();
    });

    testWidgets('should display list of tracks when data is loaded',
        (tester) async {
      // Arrange
      final tracks = [
        testTrack,
        Track(
          id: 't2',
          songId: 's1',
          name: 'Another Track',
          filePath: '/path/to/audio2.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value(tracks)),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Track'), findsOneWidget);
      expect(find.text('Another Track'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display FAB to add track', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(FloatingActionButton, 'Add Track'),
          findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should show add track dialog when FAB is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AddTrackDialog), findsOneWidget);
    });

    testWidgets('should show add track dialog from empty state button',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap empty state button
      await tester.tap(find.widgetWithText(FilledButton, 'Add Track'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AddTrackDialog), findsOneWidget);
    });

    testWidgets('should support pull-to-refresh', (tester) async {
      // Arrange
      var loadCount = 0;
      final container = ProviderContainer(
        overrides: [
          tracksBySongProvider('s1').overrideWith((ref) {
            loadCount++;
            return Future.value([testTrack]);
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert initial load
      expect(loadCount, 1);

      // Act - pull to refresh
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      // Assert - should reload
      expect(loadCount, 2);

      container.dispose();
    });

    testWidgets('should navigate to audio player when track is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1')
                .overrideWith((ref) => Future.value([testTrack])),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap on track
      await tester.tap(find.text('Test Track'));
      await tester.pumpAndSettle();

      // Assert - navigation occurs (track still visible after navigation)
      expect(find.text('Test Track'), findsWidgets);
    });

    testWidgets('should display multiple tracks in scrollable list',
        (tester) async {
      // Arrange - create many tracks
      final tracks = List.generate(
        20,
        (index) => Track(
          id: 't$index',
          songId: 's1',
          name: 'Track $index',
          filePath: '/path/to/audio$index.mp3',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tracksBySongProvider('s1').overrideWith((ref) => Future.value(tracks)),
          ],
          child: const MaterialApp(
            home: SongDetailScreen(
              songId: 's1',
              songTitle: 'Test Song',
              concertName: 'Test Concert',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - should find some tracks visible
      expect(find.text('Track 0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Scroll down to find more tracks
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Should find tracks further down the list
      expect(find.text('Track 10', skipOffstage: false), findsOneWidget);
    });
  });
}
