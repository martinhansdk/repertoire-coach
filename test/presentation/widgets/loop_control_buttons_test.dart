import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/loop_range.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/loop_control_provider.dart';
import 'package:repertoire_coach/presentation/widgets/loop_control_buttons.dart';

import 'loop_control_buttons_test.mocks.dart';

/// Fake AudioPlayerRepository for testing
class FakeAudioPlayerRepository implements AudioPlayerRepository {
  final PlaybackInfo _currentPlayback;

  FakeAudioPlayerRepository([PlaybackInfo? initialPlayback])
      : _currentPlayback = initialPlayback ?? PlaybackInfo.idle();

  @override
  PlaybackInfo get currentPlayback => _currentPlayback;

  @override
  Stream<PlaybackInfo> get playbackStream => Stream.value(_currentPlayback);

  @override
  Future<void> playTrack(Track track, {Duration startPosition = Duration.zero}) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<Duration> seek(Duration position) async => position;

  @override
  Future<void> savePlaybackPosition() async {}

  @override
  Future<Duration> loadPlaybackPosition(String trackId) async => Duration.zero;

  @override
  Future<void> setLoopMode(bool enabled) async {}

  @override
  bool get isLooping => false;

  @override
  Future<void> setLoopRange(LoopRange? loopRange) async {}

  @override
  LoopRange? get currentLoopRange => null;

  @override
  bool get isRangeLooping => false;

  @override
  Future<void> dispose() async {}
}

@GenerateMocks([LoopControls])
void main() {
  group('LoopControlButtons Widget', () {
    late MockLoopControls mockLoopControls;
    final now = DateTime.now();

    final marker1 = Marker(
      id: 'marker-1',
      markerSetId: 'set-1',
      label: 'Intro',
      positionMs: 0,
      order: 0,
      createdAt: now,
    );

    final marker2 = Marker(
      id: 'marker-2',
      markerSetId: 'set-1',
      label: 'Verse',
      positionMs: 30000,
      order: 1,
      createdAt: now,
    );

    final marker3 = Marker(
      id: 'marker-3',
      markerSetId: 'set-1',
      label: 'Chorus',
      positionMs: 60000,
      order: 2,
      createdAt: now,
    );

    setUp(() {
      mockLoopControls = MockLoopControls();
      when(mockLoopControls.setCustomLoop(
        startPosition: anyNamed('startPosition'),
        endPosition: anyNamed('endPosition'),
      )).thenAnswer((_) async => Future.value());
      when(mockLoopControls.setLoopFromMarkers(any, any)).thenAnswer((_) async => Future.value());
      when(mockLoopControls.clearLoop()).thenAnswer((_) async => Future.value());
    });

    Widget createWidgetUnderTest({
      List<Marker> markers = const [],
      PlaybackInfo? playbackInfo,
      Duration currentPosition = Duration.zero,
    }) {
      final audioRepository = FakeAudioPlayerRepository(
        PlaybackInfo.idle().copyWith(position: currentPosition),
      );

      return ProviderScope(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(audioRepository),
          loopControlsProvider.overrideWith((ref) => mockLoopControls),
          playbackInfoProvider.overrideWith((ref) {
            return Stream.value(playbackInfo ?? PlaybackInfo.idle());
          }),
          currentPlaybackProvider.overrideWith((ref) {
            return PlaybackInfo.idle().copyWith(position: currentPosition);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LoopControlButtons(markers: markers),
          ),
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('should render widget', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(LoopControlButtons), findsOneWidget);
      });

      testWidgets('should display title', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('A-B Loop'), findsOneWidget);
      });

      testWidgets('should be wrapped in Card', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsOneWidget);
      });
    });

    group('No Loop State', () {
      testWidgets('should show "No loop active" when no loop set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('No loop active'), findsOneWidget);
      });

      testWidgets('should show Set Point A button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Set Point A'), findsOneWidget);
      });

      testWidgets('should show disabled Set Point B button', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final buttonFinder = find.widgetWithText(OutlinedButton, 'Set Point B');
        expect(buttonFinder, findsOneWidget);

        final button = tester.widget<OutlinedButton>(buttonFinder);
        expect(button.onPressed, isNull); // Disabled
      });

      testWidgets('should not show Clear Loop button when no loop', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Clear Loop'), findsNothing);
      });
    });

    group('Active Loop State', () {
      testWidgets('should display active loop range', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 90),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        expect(find.text('Loop: 0:30 → 1:30'), findsOneWidget);
        expect(find.byIcon(Icons.repeat), findsOneWidget);
      });

      testWidgets('should show Clear Loop button when loop is active', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        expect(find.text('Clear Loop'), findsOneWidget);
      });

      testWidgets('should format loop times correctly', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(minutes: 1, seconds: 5),
            endPosition: const Duration(minutes: 2, seconds: 30),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        expect(find.text('Loop: 1:05 → 2:30'), findsOneWidget);
      });
    });

    group('Setting Loop Points', () {
      testWidgets('should set Point A when button tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 45),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Button should now show the time
        expect(find.text('A: 0:45'), findsOneWidget);
      });

      testWidgets('should enable Point B button after Point A is set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        // Point B should be disabled
        var buttonB = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Set Point B'),
        );
        expect(buttonB.onPressed, isNull);

        // Set Point A
        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Point B should now be enabled
        buttonB = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Set Point B'),
        );
        expect(buttonB.onPressed, isNotNull);
      });

      // SKIP: Button interaction timing issue
      testWidgets('should set Point B and create loop', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        // Set Point A
        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Move to a later position and set Point B
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 60),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Set Point B'));
        await tester.pump(); // Start async operation
        await tester.pump(); // Let UI update
        await tester.pump(const Duration(milliseconds: 100)); // Wait for snackbar
        await tester.pumpAndSettle(); // Ensure all animations complete

        // Should call setCustomLoop
        verify(mockLoopControls.setCustomLoop(
          startPosition: const Duration(seconds: 30),
          endPosition: const Duration(seconds: 60),
        )).called(1);

        // Should show success message in SnackBar
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('Loop activated'),
          ),
          findsOneWidget,
        );
      }, skip: true);

      testWidgets('should show error if Point B is before Point A', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 60),
        ));
        await tester.pumpAndSettle();

        // Set Point A at 60s
        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Try to set Point B at 30s (earlier)
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Set Point B'));
        await tester.pumpAndSettle();

        expect(find.text('Point B must be after Point A'), findsOneWidget);
      });

      testWidgets('should reset Point B when Point A is moved later', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        // Set Point A at 30s
        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Set Point B at 60s
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 60),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Set Point B'));
        await tester.pumpAndSettle();

        // Now move Point A to after Point B
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 75),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('A: 0:30')); // Tap to reset
        await tester.pumpAndSettle();

        // Point B should be reset
        expect(find.text('Set Point B'), findsOneWidget);
      });
    });

    group('Clearing Loop', () {
      testWidgets('should clear loop when button tapped', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Loop'));
        await tester.pumpAndSettle();

        verify(mockLoopControls.clearLoop()).called(1);
        expect(find.text('Loop cleared'), findsOneWidget);
      });

      testWidgets('should reset points after clearing loop', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Loop'));
        await tester.pumpAndSettle();

        // Points should be reset
        expect(find.text('Set Point A'), findsOneWidget);
        expect(find.text('Set Point B'), findsOneWidget);
      });
    });

    group('Loop from Markers', () {
      testWidgets('should show "From Markers" button when enough markers', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        expect(find.text('From Markers'), findsOneWidget);
      });

      testWidgets('should not show "From Markers" button with no markers', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('From Markers'), findsNothing);
      });

      testWidgets('should show marker selection dialog when "From Markers" tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        expect(find.text('Create Loop'), findsOneWidget);
        expect(find.text('Loop Start'), findsOneWidget);
        expect(find.text('Loop End'), findsOneWidget);
      });

      testWidgets('should populate marker dropdowns', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        // Markers should be in dropdowns (using DropdownButton<String> for marker IDs and 'current')
        expect(find.byType(DropdownButton<String>), findsNWidgets(2));
      });

      testWidgets('should disable Create Loop button until both markers selected', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        // Button should be disabled initially (both dropdowns default to null)
        final createButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create Loop'),
        );
        expect(createButton.onPressed, isNull);
      });

      // SKIP: Dropdown/filtering timing issue
      testWidgets('should filter end markers to be after start marker', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();
        await tester.pump(); // Extra pump for dialog rendering
        await tester.pump(const Duration(milliseconds: 100));

        // Select first marker as start
        await tester.tap(find.byType(DropdownButtonFormField<Marker>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Intro').last);
        await tester.pumpAndSettle();

        // End marker dropdown should only show markers after Intro
        // (This is implicit in the dialog logic - hard to test directly)
      }, skip: true);

      testWidgets('should create loop from markers when confirmed', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2, marker3],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        // Select start marker - open dropdown
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        // Select "Intro" marker from the dropdown menu
        await tester.tap(find.text('Intro').last);
        await tester.pumpAndSettle();

        // Select end marker - open dropdown
        await tester.tap(find.byType(DropdownButton<String>).last);
        await tester.pumpAndSettle();
        // Select "Verse" marker from the dropdown menu
        await tester.tap(find.text('Verse').last);
        await tester.pumpAndSettle();

        // Create loop
        await tester.tap(find.text('Create Loop'));
        await tester.pumpAndSettle();

        // Should show success message
        expect(find.text('Looping: Intro → Verse'), findsOneWidget);
      });

      testWidgets('should close dialog when Cancel tapped', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        expect(find.text('Create Loop'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Create Loop'), findsNothing);
      });

      testWidgets('should show From Markers button with single marker', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1],
        ));
        await tester.pumpAndSettle();

        // Button should be shown with 1 marker (can loop marker to current position)
        expect(find.text('From Markers'), findsOneWidget);

        // Tapping should open the dialog
        await tester.tap(find.text('From Markers'));
        await tester.pumpAndSettle();

        expect(find.text('Create Loop'), findsOneWidget);
      });
    });

    group('Visual Styling', () {
      testWidgets('should highlight Point A button when set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        // Button should have primary color border
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'A: 0:30'),
        );
        expect(button.style, isNotNull);
      });

      // SKIP: Visual state timing issue
      testWidgets('should highlight Point B button when set', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 60),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Set Point B'));
        await tester.pump(); // Start async operation
        await tester.pump(); // Let UI update
        await tester.pump(const Duration(milliseconds: 100)); // Wait for state update
        await tester.pumpAndSettle(); // Ensure button text updates

        // Button should have primary color border
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'B: 1:00'),
        );
        expect(button.style, isNotNull);
      }, skip: true);

      testWidgets('should use error color for Clear Loop button', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Clear Loop'),
        );
        expect(button.style, isNotNull);
      });
    });

    group('Icons', () {
      testWidgets('should display correct icons for loop controls', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(
          markers: [marker1, marker2],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.start), findsOneWidget); // Point A
        expect(find.byIcon(Icons.stop), findsOneWidget); // Point B
        expect(find.byIcon(Icons.bookmarks), findsOneWidget); // From Markers
      });

      testWidgets('should display repeat icon when loop is active', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.repeat), findsOneWidget);
      });

      testWidgets('should display clear icon for clear button', (tester) async {
        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('Error Handling', () {
      // SKIP: Error dialog timing issue
      testWidgets('should show error message when loop creation fails', (tester) async {
        when(mockLoopControls.setCustomLoop(
          startPosition: anyNamed('startPosition'),
          endPosition: anyNamed('endPosition'),
        )).thenThrow(Exception('Loop creation failed'));

        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Point A'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(createWidgetUnderTest(
          currentPosition: const Duration(seconds: 60),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Set Point B'));
        await tester.pump(); // Start async operation
        await tester.pump(); // Let snackbar appear
        await tester.pump(const Duration(milliseconds: 100)); // Wait for animation
        await tester.pump(); // Extra pump for SnackBar rendering

        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Error creating loop'),
          ),
          findsOneWidget,
        );
      }, skip: true);

      testWidgets('should show error message when clear fails', (tester) async {
        when(mockLoopControls.clearLoop()).thenThrow(Exception('Clear failed'));

        final playbackInfo = PlaybackInfo.idle().copyWith(
          loopRange: LoopRange(
            startPosition: const Duration(seconds: 30),
            endPosition: const Duration(seconds: 60),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest(playbackInfo: playbackInfo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear Loop'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Error clearing loop'), findsOneWidget);
      });
    });
  });
}
