import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/widgets/add_track_dialog.dart';

void main() {
  group('AddTrackDialog', () {
    Widget createWidgetUnderTest() {
      return const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AddTrackDialog(
              songId: 'song-1',
              songTitle: 'Test Song',
              choirId: 'choir-1',
            ),
          ),
        ),
      );
    }

    testWidgets('renders the dialog with the correct title', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Add New Track'), findsOneWidget);
    });

    testWidgets('displays the song title', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Song: Test Song'), findsOneWidget);
    });

    testWidgets('shows 200 MB max size in file field helper text', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Required - Maximum size 200 MB'), findsOneWidget);
    });

    testWidgets('shows Add and Cancel buttons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('shows track name and audio file form fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Track Name'), findsOneWidget);
      expect(find.text('Audio File *'), findsOneWidget);
    });

    testWidgets('shows validation error when submitting without selecting a file', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Enter a valid track name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Track Name'),
        'My Track',
      );

      // Tap the Add button without selecting a file
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Should show a validation error about missing file
      expect(find.text('Please select an audio file'), findsOneWidget);
    });
  });
}
