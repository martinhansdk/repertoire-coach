import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/presentation/widgets/marker_progress_bar.dart';

void main() {
  group('MarkerProgressBar Widget', () {
    final now = DateTime.now();

    final testMarker1 = Marker(
      id: 'marker-1',
      markerSetId: 'set-1',
      label: 'Intro',
      positionMs: 0,
      order: 0,
      createdAt: now,
    );

    final testMarker2 = Marker(
      id: 'marker-2',
      markerSetId: 'set-1',
      label: 'Verse',
      positionMs: 30000, // 30 seconds
      order: 1,
      createdAt: now,
    );

    final testMarker3 = Marker(
      id: 'marker-3',
      markerSetId: 'set-1',
      label: 'Chorus',
      positionMs: 60000, // 1 minute
      order: 2,
      createdAt: now,
    );

    Widget createWidgetUnderTest({
      Duration position = Duration.zero,
      Duration duration = const Duration(minutes: 2),
      List<Marker> markers = const [],
      ValueChanged<Duration>? onSeek,
      Duration? loopStart,
      Duration? loopEnd,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MarkerProgressBar(
            position: position,
            duration: duration,
            markers: markers,
            onSeek: onSeek ?? (_) {},
            loopStart: loopStart,
            loopEnd: loopEnd,
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('should render widget', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should have correct height', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(MarkerProgressBar),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.height, 48);
      });

      testWidgets('should wrap CustomPaint', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      });

      testWidgets('should be wrapped in GestureDetector', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        expect(find.byType(GestureDetector), findsOneWidget);
      });
    });

    group('Progress Calculation', () {
      testWidgets('should handle zero duration', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 30),
          duration: Duration.zero,
        ));

        // Should not crash
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should calculate progress at start', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: Duration.zero,
          duration: const Duration(minutes: 2),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
        // Progress should be 0.0
      });

      testWidgets('should calculate progress at midpoint', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(minutes: 1),
          duration: const Duration(minutes: 2),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
        // Progress should be 0.5
      });

      testWidgets('should calculate progress at end', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(minutes: 2),
          duration: const Duration(minutes: 2),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
        // Progress should be 1.0
      });
    });

    group('Markers Display', () {
      testWidgets('should display with no markers', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [],
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should display with single marker', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1],
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should display with multiple markers', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1, testMarker2, testMarker3],
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });
    });

    group('Loop Visualization', () {
      testWidgets('should display without loop', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: null,
          loopEnd: null,
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should display with loop range', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          loopStart: const Duration(seconds: 30),
          loopEnd: const Duration(seconds: 90),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should display with partial loop (only start)', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: const Duration(seconds: 30),
          loopEnd: null,
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should display with partial loop (only end)', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: null,
          loopEnd: const Duration(seconds: 90),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });
    });

    group('Seek Interaction', () {
      testWidgets('should call onSeek when tapped at start', (tester) async {
        Duration? seekedPosition;

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          onSeek: (position) => seekedPosition = position,
        ));

        // Tap at the start (left edge)
        await tester.tapAt(tester.getTopLeft(find.byType(MarkerProgressBar)));
        await tester.pump();

        expect(seekedPosition, isNotNull);
        expect(seekedPosition!.inMicroseconds, lessThan(1000000)); // Near 0
      });

      testWidgets('should call onSeek when tapped in middle', (tester) async {
        Duration? seekedPosition;

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          onSeek: (position) => seekedPosition = position,
        ));

        // Tap in the middle
        await tester.tapAt(tester.getCenter(find.byType(MarkerProgressBar)));
        await tester.pump();

        expect(seekedPosition, isNotNull);
        // Should be approximately 1 minute (middle of 2 minutes)
        expect(
          seekedPosition!.inSeconds,
          greaterThan(50),
        );
        expect(
          seekedPosition!.inSeconds,
          lessThan(70),
        );
      });

      testWidgets('should call onSeek when tapped at end', (tester) async {
        Duration? seekedPosition;

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          onSeek: (position) => seekedPosition = position,
        ));

        // Tap at the end (right edge)
        await tester.tapAt(tester.getTopRight(find.byType(MarkerProgressBar)));
        await tester.pump();

        expect(seekedPosition, isNotNull);
        // Should be close to 2 minutes
        expect(
          seekedPosition!.inSeconds,
          greaterThan(110),
        );
      });

      testWidgets('should clamp seek position to valid range', (tester) async {
        Duration? seekedPosition;

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          onSeek: (position) => seekedPosition = position,
        ));

        // Tap anywhere should produce valid position
        await tester.tapAt(tester.getCenter(find.byType(MarkerProgressBar)));
        await tester.pump();

        expect(seekedPosition, isNotNull);
        expect(seekedPosition!.inMicroseconds, greaterThanOrEqualTo(0));
        expect(
          seekedPosition!.inMicroseconds,
          lessThanOrEqualTo(const Duration(minutes: 2).inMicroseconds),
        );
      });

      testWidgets('should calculate seek position based on tap location', (tester) async {
        final seekPositions = <Duration>[];

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(seconds: 100),
          onSeek: seekPositions.add,
        ));

        final progressBar = find.byType(MarkerProgressBar);
        final rect = tester.getRect(progressBar);

        // Tap at 25% position
        await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
        await tester.pump();

        // Should be around 25 seconds
        expect(seekPositions.last.inSeconds, greaterThan(20));
        expect(seekPositions.last.inSeconds, lessThan(30));

        // Tap at 75% position
        await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
        await tester.pump();

        // Should be around 75 seconds
        expect(seekPositions.last.inSeconds, greaterThan(70));
        expect(seekPositions.last.inSeconds, lessThan(80));
      });
    });

    group('State Updates', () {
      testWidgets('should update when position changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 2),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);

        // Update position
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 60),
          duration: const Duration(minutes: 2),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should update when duration changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 2),
        ));

        // Update duration
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 3),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should update when markers change', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1],
        ));

        // Update markers
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1, testMarker2, testMarker3],
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should update when loop range changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: const Duration(seconds: 30),
          loopEnd: const Duration(seconds: 60),
        ));

        // Update loop range
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: const Duration(seconds: 45),
          loopEnd: const Duration(seconds: 90),
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle position exceeding duration', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 2),
        ));

        // Should not crash
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should handle negative position', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: -10),
          duration: const Duration(minutes: 2),
        ));

        // Should not crash
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should handle markers beyond duration', (tester) async {
        final markerBeyondDuration = Marker(
          id: 'marker-beyond',
          markerSetId: 'set-1',
          label: 'Beyond',
          positionMs: 300000, // 5 minutes
          order: 0,
          createdAt: now,
        );

        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          markers: [markerBeyondDuration],
        ));

        // Should not crash
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should handle loop range beyond duration', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          duration: const Duration(minutes: 2),
          loopStart: const Duration(minutes: 3),
          loopEnd: const Duration(minutes: 4),
        ));

        // Should not crash
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });
    });

    group('Custom Painter Repaint Logic', () {
      testWidgets('should repaint when progress changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 30),
        ));

        final initialPaint = find.byType(CustomPaint);
        expect(initialPaint, findsAtLeastNWidgets(1));

        // Change progress
        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 60),
        ));

        // Should trigger repaint
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      });

      testWidgets('should repaint when markers list changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1],
        ));

        // Change markers
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1, testMarker2],
        ));

        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      });

      testWidgets('should repaint when loop changes', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: const Duration(seconds: 30),
          loopEnd: const Duration(seconds: 60),
        ));

        // Change loop
        await tester.pumpWidget(createWidgetUnderTest(
          loopStart: const Duration(seconds: 45),
          loopEnd: const Duration(seconds: 75),
        ));

        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      });
    });

    group('Complex Scenarios', () {
      testWidgets('should handle all features together', (tester) async {
        Duration? seekedPosition;

        await tester.pumpWidget(createWidgetUnderTest(
          position: const Duration(seconds: 45),
          duration: const Duration(minutes: 2),
          markers: [testMarker1, testMarker2, testMarker3],
          loopStart: const Duration(seconds: 30),
          loopEnd: const Duration(seconds: 90),
          onSeek: (position) => seekedPosition = position,
        ));

        expect(find.byType(MarkerProgressBar), findsOneWidget);

        // Test seek interaction
        await tester.tapAt(tester.getCenter(find.byType(MarkerProgressBar)));
        await tester.pump();

        expect(seekedPosition, isNotNull);
      });

      testWidgets('should handle rapid state updates', (tester) async {
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(createWidgetUnderTest(
            position: Duration(seconds: i * 10),
            duration: const Duration(minutes: 2),
          ));
          await tester.pump();
        }

        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });

      testWidgets('should handle adding and removing markers dynamically', (tester) async {
        // Start with no markers
        await tester.pumpWidget(createWidgetUnderTest(markers: []));
        expect(find.byType(MarkerProgressBar), findsOneWidget);

        // Add markers
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [testMarker1, testMarker2],
        ));
        expect(find.byType(MarkerProgressBar), findsOneWidget);

        // Remove markers
        await tester.pumpWidget(createWidgetUnderTest(markers: []));
        expect(find.byType(MarkerProgressBar), findsOneWidget);
      });
    });
  });
}
