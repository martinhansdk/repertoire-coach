import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/repositories/marker_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/screens/marker_manager_screen.dart';

void main() {
  group('MarkerManagerScreen Widget', () {
    late db.AppDatabase database;
    late LocalMarkerDataSource dataSource;
    late MarkerRepositoryImpl repository;

    const String testTrackId = 'track-1';
    const String testTrackName = 'Test Track';
    const String testUserId = 'local-user-1';

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalMarkerDataSource(database);
      repository = MarkerRepositoryImpl(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    Widget createWidgetUnderTest({
      Future<List<MarkerSet>>? markerSetsFuture,
    }) {
      return ProviderScope(
        overrides: [
          markerRepositoryProvider.overrideWithValue(repository),
          if (markerSetsFuture != null)
            markerSetsByTrackProvider((testTrackId, testUserId))
                .overrideWith((ref) => markerSetsFuture),
        ],
        child: const MaterialApp(
          home: MarkerManagerScreen(
            trackId: testTrackId,
            trackName: testTrackName,
          ),
        ),
      );
    }

    group('App Bar', () {
      testWidgets('should display correct title and track name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Markers'), findsOneWidget);
        expect(find.text(testTrackName), findsOneWidget);
      });

      testWidgets('should have back button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('should display empty state when no marker sets exist', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No Marker Sets Yet'), findsOneWidget);
        expect(find.text('Create a marker set to organize section markers for this track.'), findsOneWidget);
        expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
        expect(find.text('Create Marker Set'), findsOneWidget);
      });

      testWidgets('should show create dialog when tapping create button in empty state', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create Marker Set'));
        await tester.pumpAndSettle();

        expect(find.text('New Marker Set'), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('should show loading indicator while loading marker sets', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.delayed(
            const Duration(seconds: 1),
            () => [],
          ),
        ));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Error State', () {
      testWidgets('should display error state on failure', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.error('Database error'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Error Loading Marker Sets'), findsOneWidget);
        expect(find.text('Database error'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should retry loading when retry button tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.error('Network error'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Network error'), findsOneWidget);

        // Tap retry
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Should attempt to reload (in real app would show loading)
      });
    });

    group('Success State with Marker Sets', () {
      final testMarkerSet1 = MarkerSet(
        id: 'set-1',
        trackId: testTrackId,
        name: 'Structure',
        isShared: false,
        createdByUserId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final testMarkerSet2 = MarkerSet(
        id: 'set-2',
        trackId: testTrackId,
        name: 'Rehearsal Marks',
        isShared: true,
        createdByUserId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testWidgets('should display marker sets in a list', (tester) async {
        // First create marker sets in database
        await repository.createMarkerSet(testMarkerSet1);
        await repository.createMarkerSet(testMarkerSet2);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Structure'), findsOneWidget);
        expect(find.text('Rehearsal Marks'), findsOneWidget);
      });

      testWidgets('should show correct icons for private and shared marker sets', (tester) async {
        await repository.createMarkerSet(testMarkerSet1);
        await repository.createMarkerSet(testMarkerSet2);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Find icons (lock for private, people for shared)
        expect(find.byIcon(Icons.lock), findsOneWidget);
        expect(find.byIcon(Icons.people), findsOneWidget);
      });

      testWidgets('should display marker sets in expansion tiles', (tester) async {
        await repository.createMarkerSet(testMarkerSet1);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsOneWidget);
      });

      testWidgets('should pull to refresh marker sets', (tester) async {
        await repository.createMarkerSet(testMarkerSet1);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Pull to refresh
        await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
        await tester.pumpAndSettle();

        // Should reload data
        expect(find.text('Structure'), findsOneWidget);
      });
    });

    group('Marker Set Actions', () {
      final testMarkerSet = MarkerSet(
        id: 'set-1',
        trackId: testTrackId,
        name: 'Test Set',
        isShared: false,
        createdByUserId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testWidgets('should show popup menu for marker set', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Find and tap popup menu button
        await tester.tap(find.byType(PopupMenuButton).first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('should show edit dialog when edit menu item tapped', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open popup menu
        await tester.tap(find.byType(PopupMenuButton).first);
        await tester.pumpAndSettle();

        // Tap Edit
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Marker Set'), findsOneWidget);
      });

      testWidgets('should show delete confirmation when delete menu item tapped', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open popup menu
        await tester.tap(find.byType(PopupMenuButton).first);
        await tester.pumpAndSettle();

        // Tap Delete
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Marker Set'), findsOneWidget);
        expect(find.text('Are you sure you want to delete "Test Set" and all its markers?'), findsOneWidget);
      });

      testWidgets('should cancel delete when cancel button tapped', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open delete dialog
        await tester.tap(find.byType(PopupMenuButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Marker set should still exist
        expect(find.text('Test Set'), findsOneWidget);
      });

      testWidgets('should delete marker set when confirmed', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Test Set'), findsOneWidget);

        // Open delete dialog
        await tester.tap(find.byType(PopupMenuButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Confirm delete
        final deleteButton = find.widgetWithText(FilledButton, 'Delete');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Should show success message
        expect(find.text('Marker set deleted successfully'), findsOneWidget);
      });
    });

    group('Markers within Marker Sets', () {
      final testMarkerSet = MarkerSet(
        id: 'set-1',
        trackId: testTrackId,
        name: 'Structure',
        isShared: false,
        createdByUserId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testWidgets('should show empty markers state when marker set has no markers', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Expand the marker set
        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        expect(find.text('No markers yet'), findsOneWidget);
        expect(find.text('Add Marker'), findsOneWidget);
      });

      testWidgets('should show add marker button in empty state', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        // Find and tap Add Marker button
        await tester.tap(find.text('Add Marker').first);
        await tester.pumpAndSettle();

        expect(find.text('Add Marker'), findsAtLeastNWidgets(1)); // Dialog title
      });

      testWidgets('should display markers in the expanded marker set', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker1 = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Intro',
          positionMs: 0,
          order: 0,
          createdAt: DateTime.now(),
        );

        final marker2 = Marker(
          id: 'marker-2',
          markerSetId: testMarkerSet.id,
          label: 'Verse 1',
          positionMs: 30000,
          order: 1,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker1);
        await repository.createMarker(marker2);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Expand marker set
        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        expect(find.text('Intro'), findsOneWidget);
        expect(find.text('Verse 1'), findsOneWidget);
        expect(find.text('0:00.000'), findsOneWidget);
        expect(find.text('0:30.000'), findsOneWidget);
      });

      testWidgets('should show marker popup menu', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Chorus',
          positionMs: 60000,
          order: 0,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        // Find marker's popup menu
        await tester.tap(find.byType(PopupMenuButton).last);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsWidgets);
        expect(find.text('Delete'), findsWidgets);
      });

      testWidgets('should show edit marker dialog when edit tapped', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Bridge',
          positionMs: 90000,
          order: 0,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        // Open marker menu and edit
        await tester.tap(find.byType(PopupMenuButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit').last);
        await tester.pumpAndSettle();

        expect(find.text('Edit Marker'), findsOneWidget);
      });

      testWidgets('should show delete marker confirmation', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Outro',
          positionMs: 120000,
          order: 0,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        // Open marker menu and delete
        await tester.tap(find.byType(PopupMenuButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        expect(find.text('Delete Marker'), findsOneWidget);
        expect(find.text('Are you sure you want to delete "Outro"?'), findsOneWidget);
      });

      testWidgets('should delete marker when confirmed', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Solo',
          positionMs: 75000,
          order: 0,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Structure'));
        await tester.pumpAndSettle();

        expect(find.text('Solo'), findsOneWidget);

        // Delete marker
        await tester.tap(find.byType(PopupMenuButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        final deleteButton = find.widgetWithText(FilledButton, 'Delete');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        expect(find.text('Marker deleted successfully'), findsOneWidget);
      });
    });

    group('Floating Action Button', () {
      testWidgets('should display floating action button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('New Set'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should show create marker set dialog when FAB tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSetsFuture: Future.value([]),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('New Marker Set'), findsOneWidget);
      });
    });

    group('Time Formatting', () {
      final testMarkerSet = MarkerSet(
        id: 'set-1',
        trackId: testTrackId,
        name: 'Test',
        isShared: false,
        createdByUserId: testUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testWidgets('should format marker time correctly', (tester) async {
        await repository.createMarkerSet(testMarkerSet);

        final marker = Marker(
          id: 'marker-1',
          markerSetId: testMarkerSet.id,
          label: 'Test',
          positionMs: 125500, // 2 min 5.5 sec
          order: 0,
          createdAt: DateTime.now(),
        );

        await repository.createMarker(marker);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Test'));
        await tester.pumpAndSettle();

        expect(find.text('2:05.500'), findsOneWidget);
      });
    });
  });
}
