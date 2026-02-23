import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/presentation/providers/selected_marker_set_provider.dart';
import 'package:repertoire_coach/presentation/widgets/marker_set_selector.dart';

void main() {
  group('MarkerSetSelector Widget', () {
    final now = DateTime.now();

    final markerSet1 = MarkerSet(
      id: 'set-1',
      trackId: 'track-1',
      name: 'Structure',
      isShared: false,
      isTimeSynced: true,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    final markerSet2 = MarkerSet(
      id: 'set-2',
      trackId: 'track-1',
      name: 'Rehearsal Marks',
      isShared: true,
      isTimeSynced: true,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    final markerSet3 = MarkerSet(
      id: 'set-3',
      trackId: 'track-1',
      name: 'Bar Numbers',
      isShared: false,
      isTimeSynced: true,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    Widget createWidgetUnderTest({
      List<MarkerSet> markerSets = const [],
      VoidCallback? onManageMarkers,
      String? initialSelectedId,
    }) {
      return ProviderScope(
        overrides: [
          selectedMarkerSetProvider.overrideWith((ref) => initialSelectedId),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkerSetSelector(
              markerSets: markerSets,
              onManageMarkers: onManageMarkers,
            ),
          ),
        ),
      );
    }

    group('Empty State', () {
      testWidgets('should display chip with bookmarks icon when no marker sets', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(ActionChip), findsOneWidget);
        expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
        expect(find.text('Markers'), findsOneWidget);
      });

      testWidgets('should call onManageMarkers when empty chip is tapped', (tester) async {
        bool manageTapped = false;

        await tester.pumpWidget(createWidgetUnderTest(
          onManageMarkers: () => manageTapped = true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pump();

        expect(manageTapped, true);
      });

      testWidgets('should show chip even when onManageMarkers is null', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          onManageMarkers: null,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ActionChip), findsOneWidget);
        expect(find.text('Markers'), findsOneWidget);
      });
    });

    group('Chip Display', () {
      testWidgets('should show ActionChip with selected set name', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
          initialSelectedId: 'set-1',
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ActionChip), findsOneWidget);
        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should select first marker set by default', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should auto-select valid initial selection', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
          initialSelectedId: 'set-2',
        ));
        await tester.pumpAndSettle();

        expect(find.text('Rehearsal Marks'), findsOneWidget);
      });

      testWidgets('should fall back to first item if initial selection is invalid', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
          initialSelectedId: 'invalid-id',
        ));
        await tester.pumpAndSettle();

        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should show bookmarks icon on chip', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmarks), findsOneWidget);
      });
    });

    group('Bottom Sheet', () {
      testWidgets('should open bottom sheet when chip is tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.text('Marker sets'), findsOneWidget);
      });

      testWidgets('should show all marker sets in bottom sheet', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        // 'Structure' appears in both the chip (background) and the sheet
        expect(find.text('Structure'), findsWidgets);
        expect(find.text('Rehearsal Marks'), findsOneWidget);
        expect(find.text('Bar Numbers'), findsOneWidget);
      });

      testWidgets('should show checkmark next to currently selected set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
          initialSelectedId: 'set-1',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should show lock icon for private sets in sheet', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock), findsOneWidget);
      });

      testWidgets('should show people icon for shared sets in sheet', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet2],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people), findsOneWidget);
      });

      testWidgets('should update selection and close sheet when set is tapped', (tester) async {
        String? selectedId;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                selectedId = ref.watch(selectedMarkerSetProvider);
                return MaterialApp(
                  home: Scaffold(
                    body: MarkerSetSelector(
                      markerSets: [markerSet1, markerSet2],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open sheet
        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        // Select second set
        await tester.tap(find.text('Rehearsal Marks'));
        await tester.pumpAndSettle();

        expect(selectedId, 'set-2');
        // Sheet should be dismissed
        expect(find.text('Marker sets'), findsNothing);
        // Chip should now show selected name
        expect(find.text('Rehearsal Marks'), findsOneWidget);
      });
    });

    group('Manage Markers', () {
      testWidgets('should show edit button in sheet when onManageMarkers provided', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () {},
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byTooltip('Manage markers'), findsOneWidget);
      });

      testWidgets('should not show edit button in sheet when onManageMarkers is null', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: null,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit), findsNothing);
      });

      testWidgets('should close sheet and call onManageMarkers when edit tapped', (tester) async {
        bool manageTapped = false;

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () => manageTapped = true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        expect(manageTapped, true);
        // Sheet should be dismissed
        expect(find.text('Marker sets'), findsNothing);
      });
    });

    group('State Management', () {
      testWidgets('should handle marker sets list changing', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
        ));
        await tester.pumpAndSettle();

        // Update to different marker sets
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet3],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Bar Numbers'), findsOneWidget);
      });

      testWidgets('should handle transition from empty to populated', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Markers'), findsOneWidget);

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should handle transition from populated to empty', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Structure'), findsOneWidget);

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Markers'), findsOneWidget);
      });
    });
  });
}
