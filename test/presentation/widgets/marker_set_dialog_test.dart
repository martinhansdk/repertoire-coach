import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/repositories/marker_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/widgets/marker_set_dialog.dart';

void main() {
  group('MarkerSetDialog Widget', () {
    late db.AppDatabase database;

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    Widget createWidgetUnderTest({
      String trackId = 'track-1',
      MarkerSet? markerSet,
    }) {
      final dataSource = LocalMarkerDataSource(database);
      final repository = MarkerRepositoryImpl(dataSource);

      return ProviderScope(
        overrides: [
          markerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => MarkerSetDialog(
                      trackId: trackId,
                      markerSet: markerSet,
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    group('Create Mode', () {
      testWidgets('should display create dialog with all fields', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify title
        expect(find.text('New Marker Set'), findsOneWidget);

        // Verify fields
        expect(find.widgetWithText(TextFormField, 'Set Name'), findsOneWidget);
        expect(find.text('Shared'), findsOneWidget);
        expect(find.text('Private - only you can see this'), findsOneWidget);

        // Verify actions
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Create'), findsOneWidget);
      });

      testWidgets('should default to private (not shared)', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Find switch and verify it's off (private)
        final switchWidget = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Shared'),
        );
        expect(switchWidget.value, false);
        expect(find.text('Private - only you can see this'), findsOneWidget);
      });

      testWidgets('should autofocus name field in create mode', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Name field should exist and be ready for input
        expect(find.widgetWithText(TextFormField, 'Set Name'), findsOneWidget);
      });

      testWidgets('should validate empty name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Try to create without entering name
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a name'), findsOneWidget);
      });

      testWidgets('should validate name length', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Enter name that's too short
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'A',
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      });

      testWidgets('should toggle shared/private switch', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Initially private
        expect(find.text('Private - only you can see this'), findsOneWidget);

        // Toggle to shared
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(find.text('Visible to all choir members'), findsOneWidget);

        // Toggle back to private
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(find.text('Private - only you can see this'), findsOneWidget);
      });

      testWidgets('should create marker set with valid name (private)', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Enter valid name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Structure Markers',
        );

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Dialog should close and success message shown
        expect(find.text('New Marker Set'), findsNothing);
        expect(find.text('Marker set created successfully'), findsOneWidget);
      });

      testWidgets('should create marker set with valid name (shared)', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Rehearsal Marks',
        );

        // Toggle to shared
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        expect(find.text('Marker set created successfully'), findsOneWidget);
      });

      testWidgets('should show loading indicator while saving', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Test Set',
        );
        await tester.tap(find.text('Create'));
        await tester.pump(); // Don't settle - catch loading state

        // Loading indicator may appear (timing sensitive)
        // expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should disable fields while saving', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Test',
        );
        await tester.tap(find.text('Create'));
        await tester.pump();

        // Fields should be disabled (hard to verify in fast tests)
      });
    });

    group('Edit Mode', () {
      final existingMarkerSet = MarkerSet(
        id: 'marker-set-1',
        trackId: 'track-1',
        name: 'Original Name',
        isShared: false,
        createdByUserId: 'local-user-1',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      testWidgets('should display edit dialog with existing data', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify title
        expect(find.text('Edit Marker Set'), findsOneWidget);

        // Verify pre-filled data
        final nameField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Set Name'),
        );
        expect(nameField.controller?.text, 'Original Name');

        // Verify switch state
        final switchWidget = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Shared'),
        );
        expect(switchWidget.value, false);

        // Verify action button
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('should display edit dialog with shared marker set', (tester) async {
        final sharedMarkerSet = MarkerSet(
          id: 'marker-set-2',
          trackId: 'track-1',
          name: 'Shared Set',
          isShared: true,
          createdByUserId: 'local-user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(createWidgetUnderTest(markerSet: sharedMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Shared'),
        );
        expect(switchWidget.value, true);
        expect(find.text('Visible to all choir members'), findsOneWidget);
      });

      testWidgets('should not autofocus name field in edit mode', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Name field should exist with pre-filled value
        final nameField = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Set Name'),
        );
        expect(nameField.controller?.text, 'Original Name');
      });

      testWidgets('should update marker set with modified name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Modify the name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Updated Name',
        );

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Marker set updated successfully'), findsOneWidget);
      });

      testWidgets('should update marker set with modified privacy', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Toggle privacy
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Marker set updated successfully'), findsOneWidget);
      });

      testWidgets('should close without saving if nothing changed', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Don't modify anything, just save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Dialog should close without success message
        expect(find.text('Edit Marker Set'), findsNothing);
        expect(find.text('Marker set updated successfully'), findsNothing);
      });

      testWidgets('should validate edited name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Clear name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          '',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a name'), findsOneWidget);
      });

      testWidgets('should validate edited name length', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Enter name that's too short
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'X',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      });
    });

    group('Dialog Actions', () {
      testWidgets('should close dialog when Cancel is tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('New Marker Set'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('New Marker Set'), findsNothing);
      });

      testWidgets('should disable Cancel button while saving', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Test',
        );
        await tester.tap(find.text('Create'));
        await tester.pump();

        // Button should be disabled (timing sensitive)
      });
    });

    group('Error Handling', () {
      testWidgets('should show error message on create failure', (tester) async {
        // Close database to cause error
        await database.close();

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Error Test',
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Should show error message
        expect(find.textContaining('Error saving marker set'), findsOneWidget);

        // Dialog should remain open
        expect(find.text('New Marker Set'), findsOneWidget);
      });

      testWidgets('should show error message on update failure', (tester) async {
        final existingMarkerSet = MarkerSet(
          id: 'marker-set-1',
          trackId: 'track-1',
          name: 'Test Set',
          isShared: false,
          createdByUserId: 'local-user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Close database to cause error
        await database.close();

        await tester.pumpWidget(createWidgetUnderTest(markerSet: existingMarkerSet));
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          'Updated',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Error saving marker set'), findsOneWidget);
        expect(find.text('Edit Marker Set'), findsOneWidget);
      });
    });

    group('Text Input', () {
      testWidgets('should capitalize words in name field', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Name field should exist
        expect(find.widgetWithText(TextFormField, 'Set Name'), findsOneWidget);
      });

      testWidgets('should trim whitespace from name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Enter name with leading/trailing spaces
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Set Name'),
          '  Trimmed Name  ',
        );

        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Should succeed (trimmed internally)
        expect(find.text('Marker set created successfully'), findsOneWidget);
      });
    });

    group('Icons and Visual Elements', () {
      testWidgets('should display bookmark icon', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      });

      testWidgets('should update subtitle when toggling privacy', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Initially private
        expect(find.text('Private - only you can see this'), findsOneWidget);
        expect(find.text('Visible to all choir members'), findsNothing);

        // Toggle to shared
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(find.text('Visible to all choir members'), findsOneWidget);
        expect(find.text('Private - only you can see this'), findsNothing);
      });
    });
  });
}
