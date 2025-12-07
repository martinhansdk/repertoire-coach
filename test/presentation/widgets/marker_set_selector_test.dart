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
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    final markerSet2 = MarkerSet(
      id: 'set-2',
      trackId: 'track-1',
      name: 'Rehearsal Marks',
      isShared: true,
      createdByUserId: 'user-1',
      createdAt: now,
      updatedAt: now,
    );

    final markerSet3 = MarkerSet(
      id: 'set-3',
      trackId: 'track-1',
      name: 'Bar Numbers',
      isShared: false,
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
          selectedMarkerSetProvider.overrideWith((ref) {
            final notifier = SelectedMarkerSetNotifier();
            if (initialSelectedId != null) {
              notifier.select(initialSelectedId);
            }
            return notifier;
          }),
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
      testWidgets('should display empty state when no marker sets provided', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
        expect(find.text('No marker sets'), findsOneWidget);
      });

      testWidgets('should show create button in empty state when onManageMarkers provided', (tester) async {
        bool manageTapped = false;

        await tester.pumpWidget(createWidgetUnderTest(
          onManageMarkers: () => manageTapped = true,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Create'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        await tester.tap(find.text('Create'));
        await tester.pump();

        expect(manageTapped, true);
      });

      testWidgets('should not show create button when onManageMarkers is null', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          onManageMarkers: null,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Create'), findsNothing);
      });
    });

    group('Dropdown with Marker Sets', () {
      testWidgets('should display dropdown with marker sets', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        expect(find.byType(DropdownButton<String>), findsOneWidget);
      });

      testWidgets('should show all marker sets in dropdown', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        // Open dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        expect(find.text('Structure').hitTestable(), findsOneWidget);
        expect(find.text('Rehearsal Marks').hitTestable(), findsOneWidget);
        expect(find.text('Bar Numbers').hitTestable(), findsOneWidget);
      });

      testWidgets('should show correct icon for private marker set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        // Open dropdown to see icons
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock), findsWidgets);
      });

      testWidgets('should show correct icon for shared marker set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet2],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people), findsWidgets);
      });

      testWidgets('should select first marker set by default', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        // First item should be displayed in dropdown
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

      testWidgets('should fallback to first item if initial selection is invalid', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
          initialSelectedId: 'invalid-id',
        ));
        await tester.pumpAndSettle();

        // Should select first item
        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should change selection when different item selected', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2, markerSet3],
        ));
        await tester.pumpAndSettle();

        // Initially shows first item
        expect(find.text('Structure'), findsOneWidget);

        // Open dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        // Select different item
        await tester.tap(find.text('Rehearsal Marks').last);
        await tester.pumpAndSettle();

        // Should show selected item
        expect(find.text('Rehearsal Marks'), findsOneWidget);
      });

      testWidgets('should update provider when selection changes', (tester) async {
        String? selectedId;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                selectedId = ref.watch(selectedMarkerSetProvider).selectedMarkerSetId;
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

        // Open dropdown and select second item
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rehearsal Marks').last);
        await tester.pumpAndSettle();

        expect(selectedId, 'set-2');
      });
    });

    group('Manage Button', () {
      testWidgets('should show manage button when onManageMarkers provided', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () {},
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byTooltip('Manage Markers'), findsOneWidget);
      });

      testWidgets('should not show manage button when onManageMarkers is null', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: null,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit), findsNothing);
      });

      testWidgets('should call onManageMarkers when manage button tapped', (tester) async {
        bool manageTapped = false;

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () => manageTapped = true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit));
        await tester.pump();

        expect(manageTapped, true);
      });
    });

    group('Layout', () {
      testWidgets('should use Row layout with dropdown and optional button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () {},
        ));
        await tester.pumpAndSettle();

        expect(find.byType(Row), findsWidgets);
        expect(find.byType(Expanded), findsAtLeastNWidgets(1)); // Dropdown should be expanded
      });

      testWidgets('should have proper spacing between dropdown and button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
          onManageMarkers: () {},
        ));
        await tester.pumpAndSettle();

        // SizedBox with width 8 should exist
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((box) => box.width == 8), true);
      });
    });

    group('Dropdown Behavior', () {
      testWidgets('should expand dropdown to full width', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        expect(dropdown.isExpanded, true);
      });

      testWidgets('should handle long marker set names with ellipsis', (tester) async {
        final longNameMarkerSet = MarkerSet(
          id: 'set-long',
          trackId: 'track-1',
          name: 'This is a very long marker set name that should be truncated',
          isShared: false,
          createdByUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [longNameMarkerSet],
        ));
        await tester.pumpAndSettle();

        // Find the Text widget with overflow
        final textWidget = tester.widget<Text>(
          find.text('This is a very long marker set name that should be truncated'),
        );
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });

      testWidgets('should display all dropdown items correctly', (tester) async {
        final markerSets = List.generate(
          5,
          (i) => MarkerSet(
            id: 'set-$i',
            trackId: 'track-1',
            name: 'Set $i',
            isShared: i % 2 == 0,
            createdByUserId: 'user-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: markerSets,
        ));
        await tester.pumpAndSettle();

        // Open dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        // Should show all 5 items
        for (int i = 0; i < 5; i++) {
          expect(find.text('Set $i'), findsWidgets);
        }
      });
    });

    group('State Management', () {
      testWidgets('should maintain selection across rebuilds', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
        ));
        await tester.pumpAndSettle();

        // Select second item
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rehearsal Marks').last);
        await tester.pumpAndSettle();

        expect(find.text('Rehearsal Marks'), findsOneWidget);

        // Rebuild widget
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
        ));
        await tester.pumpAndSettle();

        // Selection should be maintained
        expect(find.text('Rehearsal Marks'), findsOneWidget);
      });

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

        // Should show new marker set
        expect(find.text('Bar Numbers'), findsOneWidget);
      });

      testWidgets('should handle transition from empty to populated', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('No marker sets'), findsOneWidget);

        // Add marker sets
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        expect(find.byType(DropdownButton<String>), findsOneWidget);
        expect(find.text('Structure'), findsOneWidget);
      });

      testWidgets('should handle transition from populated to empty', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1],
        ));
        await tester.pumpAndSettle();

        expect(find.byType(DropdownButton<String>), findsOneWidget);

        // Remove marker sets
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('No marker sets'), findsOneWidget);
      });
    });

    group('Icons and Visual Elements', () {
      testWidgets('should show private icon in empty state', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
      });

      testWidgets('should show both private and shared icons in dropdown', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markerSets: [markerSet1, markerSet2],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock), findsWidgets);
        expect(find.byIcon(Icons.people), findsWidgets);
      });
    });
  });
}
