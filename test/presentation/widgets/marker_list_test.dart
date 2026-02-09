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
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MarkerList(
          markers: markers,
          currentPosition: currentPosition,
          onMarkerTap: onMarkerTap,
          showPositions: true,
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
}
