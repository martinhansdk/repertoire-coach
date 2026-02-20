import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:repertoire_coach/domain/repositories/marker_repository.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_sync_provider.dart';
import 'package:repertoire_coach/presentation/screens/marker_sync/text_input_step.dart';

import 'text_input_step_test.mocks.dart';

@GenerateMocks([MarkerRepository])
void main() {
  group('TextInputStep Widget', () {
    late MockMarkerRepository mockRepository;

    setUp(() {
      mockRepository = MockMarkerRepository();
    });

    Widget createWidgetUnderTest({List<Marker>? markers}) {
      return ProviderScope(
        overrides: [
          markerRepositoryProvider.overrideWithValue(mockRepository),
          markerSyncNotifierProvider(
            const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
          ).overrideWith((ref) => MarkerSyncNotifier(
                markerRepository: mockRepository,
                trackId: 'track-1',
                markerSetId: 'set-1',
              )),
          if (markers != null)
            markersByMarkerSetProvider('set-1')
                .overrideWith((ref) => Future.value(markers)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TextInputStep(
              params: MarkerSyncParams(
                trackId: 'track-1',
                markerSetId: 'set-1',
              ),
            ),
          ),
        ),
      );
    }

    group('UI Rendering', () {
      testWidgets('does not display helper text above the editor', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('Enter one marker per line'), findsNothing);
        expect(find.text('Examples: verse, chorus, intro, bridge, or lyrics'), findsNothing);
        expect(find.text('Empty lines are preserved for visual spacing'), findsNothing);
      });

      testWidgets('displays text input field with hint text', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.byType(TextField), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, contains('intro'));
        expect(textField.decoration?.hintText, contains('verse 1'));
        expect(textField.decoration?.hintText, contains('chorus'));
      });

      testWidgets('displays save and time sync buttons', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.byKey(const ValueKey('markerSyncSaveTextButton')), findsOneWidget);
        expect(find.byKey(const ValueKey('markerSyncNextButton')), findsOneWidget);
      });

      testWidgets('displays line counter', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.byIcon(Icons.list_alt), findsOneWidget);
        expect(find.text('1 lines (0 non-empty)'), findsOneWidget);
      });

      testWidgets('text field is autofocused', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, true);
      });

      testWidgets('text field expands to fill available space', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.expands, true);
        expect(textField.maxLines, null);
      });

      testWidgets('prepopulates text when markers exist', (tester) async {
        final markers = [
          Marker(
            id: 'm2',
            markerSetId: 'set-1',
            label: 'Chorus',
            positionMs: 20000,
            order: 1,
            createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
          ),
          Marker(
            id: 'm1',
            markerSetId: 'set-1',
            label: 'Verse',
            positionMs: 10000,
            order: 0,
            createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        await tester.pumpWidget(createWidgetUnderTest(markers: markers));
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'Verse\nChorus');
      });

    });

    group('Line Counter', () {
      testWidgets('shows 1 line (0 non-empty) for empty text', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('1 lines (0 non-empty)'), findsOneWidget);
      });

      testWidgets('updates counter when text is entered', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\nchorus\nbridge');
        await tester.pump();

        expect(find.text('3 lines (3 non-empty)'), findsOneWidget);
      });

      testWidgets('counts empty lines correctly', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\n\nchorus\n\nbridge');
        await tester.pump();

        expect(find.text('5 lines (3 non-empty)'), findsOneWidget);
      });

      testWidgets('handles only empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\n\n');
        await tester.pump();

        expect(find.text('4 lines (0 non-empty)'), findsOneWidget);
      });

      testWidgets('counts whitespace-only lines as empty', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\n   \nchorus');
        await tester.pump();

        expect(find.text('3 lines (2 non-empty)'), findsOneWidget);
      });
    });

    group('Next Button State', () {
      testWidgets('next button is disabled when no text entered', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncNextButton')),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('next button is disabled when only empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\n\n');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncNextButton')),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('next button is disabled for whitespace-only lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '   \n  \n\t\t');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncNextButton')),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('next button is enabled when at least one non-empty line', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncNextButton')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('next button is enabled with mix of empty and non-empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\nverse\n\n');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncNextButton')),
        );
        expect(button.onPressed, isNotNull);
      });
    });

    group('Warning Messages', () {
      testWidgets('shows warning when text is not empty but only has empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\n');
        await tester.pump();

        expect(find.text('Please enter at least one non-empty line'), findsOneWidget);
      });

      testWidgets('does not show warning when completely empty', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('Please enter at least one non-empty line'), findsNothing);
      });

      testWidgets('does not show warning when has non-empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse');
        await tester.pump();

        expect(find.text('Please enter at least one non-empty line'), findsNothing);
      });

      testWidgets('warning disappears when valid text is entered', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\n');
        await tester.pump();
        expect(find.text('Please enter at least one non-empty line'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'verse');
        await tester.pump();
        expect(find.text('Please enter at least one non-empty line'), findsNothing);
      });
    });

    group('Text Entry', () {
      testWidgets('accepts single line input', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'verse');
      });

      testWidgets('accepts multi-line input', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\nchorus\nbridge');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'verse\nchorus\nbridge');
      });

      testWidgets('accepts input with special characters', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse #1\nchorus (repeat)');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'verse #1\nchorus (repeat)');
      });

      testWidgets('text can be edited after entry', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse');
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'chorus');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'chorus');
      });
    });

    group('Edge Cases', () {
      testWidgets('handles very long text input', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final longText = List.generate(100, (i) => 'line-$i').join('\n');
        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        expect(find.text('100 lines (100 non-empty)'), findsOneWidget);
      });

      testWidgets('handles text with trailing newlines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\nchorus\n\n\n');
        await tester.pump();

        expect(find.text('5 lines (2 non-empty)'), findsOneWidget);
      });

      testWidgets('handles text with leading newlines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\n\nverse\nchorus');
        await tester.pump();

        expect(find.text('4 lines (2 non-empty)'), findsOneWidget);
      });

      testWidgets('handles text with consecutive empty lines', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), 'verse\n\n\n\nchorus');
        await tester.pump();

        expect(find.text('5 lines (2 non-empty)'), findsOneWidget);
      });

      testWidgets('handles text with tabs and spaces', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(find.byType(TextField), '\t\t\n   \nverse');
        await tester.pump();

        expect(find.text('3 lines (1 non-empty)'), findsOneWidget);
      });
    });
  });
}
