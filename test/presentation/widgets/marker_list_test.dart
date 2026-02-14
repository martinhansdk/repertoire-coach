import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/presentation/widgets/marker_list.dart';

void main() {
  List<Marker> buildMarkers() {
    return [
      Marker(
        id: 'm1',
        markerSetId: 'set-1',
        label: 'Verse',
        positionMs: 0,
        order: 0,
        createdAt: DateTime(2024, 1, 1),
      ),
      Marker(
        id: 'm2',
        markerSetId: 'set-1',
        label: 'Chorus',
        positionMs: 10000,
        order: 1,
        createdAt: DateTime(2024, 1, 1),
      ),
      Marker(
        id: 'm3',
        markerSetId: 'set-1',
        label: 'Bridge',
        positionMs: 20000,
        order: 2,
        createdAt: DateTime(2024, 1, 1),
      ),
    ];
  }

  Widget buildWidget({
    required List<Marker> markers,
    required Duration currentPosition,
    ValueChanged<Duration>? onMarkerTap,
    bool isPlaying = false,
    Duration? trackDuration,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MarkerList(
          markers: markers,
          currentPosition: currentPosition,
          onMarkerTap: onMarkerTap,
          showPositions: true,
          isPlaying: isPlaying,
          trackDuration: trackDuration,
        ),
      ),
    );
  }

  testWidgets('renders markers as plain text without numbering or timestamps', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        markers: buildMarkers(),
        currentPosition: Duration.zero,
        onMarkerTap: (_) {},
      ),
    );

    expect(find.text('Verse'), findsOneWidget);
    expect(find.text('Chorus'), findsOneWidget);
    expect(find.text('Bridge'), findsOneWidget);

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.text('0:00.000'), findsNothing);
    expect(find.text('0:10.000'), findsNothing);
  });

  testWidgets('renders empty markers as blank lines', (tester) async {
    final markers = [
      Marker(
        id: 'm1',
        markerSetId: 'set-1',
        label: 'Line 1',
        positionMs: 0,
        order: 0,
        createdAt: DateTime(2024, 1, 1),
      ),
      Marker(
        id: 'm2',
        markerSetId: 'set-1',
        label: '',
        positionMs: 5000,
        order: 1,
        createdAt: DateTime(2024, 1, 1),
      ),
      Marker(
        id: 'm3',
        markerSetId: 'set-1',
        label: 'Line 2',
        positionMs: 10000,
        order: 2,
        createdAt: DateTime(2024, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      buildWidget(
        markers: markers,
        currentPosition: Duration.zero,
        onMarkerTap: (_) {},
      ),
    );

    expect(find.text('Line 1'), findsOneWidget);
    expect(find.text('Line 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('markerSpacer_1')), findsOneWidget);
  });

  testWidgets('uses compact row height', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        markers: buildMarkers(),
        currentPosition: Duration.zero,
        onMarkerTap: (_) {},
      ),
    );

    final listView = tester.widget<ListView>(find.byKey(const ValueKey('markerListScroll')));
    expect(listView.itemExtent, lessThanOrEqualTo(36));
  });

  testWidgets('tapping marker calls onMarkerTap with position', (tester) async {
    Duration? tapped;
    await tester.pumpWidget(
      buildWidget(
        markers: buildMarkers(),
        currentPosition: Duration.zero,
        onMarkerTap: (position) => tapped = position,
      ),
    );

    await tester.tap(find.text('Chorus'));
    await tester.pump();

    expect(tapped, const Duration(seconds: 10));
  });

  testWidgets('shows progress background for active marker', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        markers: buildMarkers(),
        currentPosition: const Duration(seconds: 5),
        onMarkerTap: (_) {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final progress = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('markerProgress_0')),
    );
    expect(progress.widthFactor, closeTo(0.5, 0.05));
  });

  testWidgets('centers active marker when it changes', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        markers: List.generate(
          30,
          (i) => Marker(
            id: 'm$i',
            markerSetId: 'set-1',
            label: 'Marker $i',
            positionMs: i * 1000,
            order: i,
            createdAt: DateTime(2024, 1, 1),
          ),
        ),
        currentPosition: const Duration(seconds: 20),
        onMarkerTap: (_) {},
      ),
    );

    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('markerListScroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  group('Animation Pause Behavior', () {
    testWidgets('pauses animation when isPlaying changes from true to false', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: true,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Animation should be running - verify progress is visible
      expect(find.byKey(const ValueKey('markerProgress_0')), findsOneWidget);

      // Change to paused
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: false,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Progress should still be visible at current position
      final progress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(progress.widthFactor, closeTo(0.5, 0.05));
    });

    testWidgets('resumes animation when isPlaying changes from false to true', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: false,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Get initial progress value
      final initialProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      final initialWidth = initialProgress.widthFactor;

      // Change to playing
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: true,
          trackDuration: const Duration(seconds: 30),
        ),
      );

      // Let animation run a bit
      await tester.pump(const Duration(milliseconds: 500));

      // Progress should have advanced
      final newProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(newProgress.widthFactor, greaterThan(initialWidth!));
    });

    testWidgets('respects isPlaying state on initial render when paused', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: false,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Progress should be visible at current position
      final progress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(progress.widthFactor, closeTo(0.5, 0.05));

      // Wait and verify it doesn't advance (since paused)
      final initialWidth = progress.widthFactor;
      await tester.pump(const Duration(milliseconds: 500));

      final unchangedProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(unchangedProgress.widthFactor, equals(initialWidth));
    });

    testWidgets('respects isPlaying state on initial render when playing', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: true,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Get initial progress value
      final initialProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      final initialWidth = initialProgress.widthFactor;

      // Let animation run
      await tester.pump(const Duration(milliseconds: 500));

      // Progress should have advanced
      final newProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(newProgress.widthFactor, greaterThan(initialWidth!));
    });

    testWidgets('maintains correct position when paused and position changes', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 5),
          onMarkerTap: (_) {},
          isPlaying: false,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify initial position
      final initialProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(initialProgress.widthFactor, closeTo(0.5, 0.05));

      // Change position while still paused
      await tester.pumpWidget(
        buildWidget(
          markers: buildMarkers(),
          currentPosition: const Duration(seconds: 7),
          onMarkerTap: (_) {},
          isPlaying: false,
          trackDuration: const Duration(seconds: 30),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Progress should reflect new position
      final newProgress = tester.widget<FractionallySizedBox>(
        find.byKey(const ValueKey('markerProgress_0')),
      );
      expect(newProgress.widthFactor, closeTo(0.7, 0.05));
    });
  });
}
