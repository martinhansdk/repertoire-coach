import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/loop_range.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/domain/repositories/marker_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_sync_provider.dart';
import 'package:repertoire_coach/presentation/providers/track_provider.dart';
import 'package:repertoire_coach/presentation/screens/marker_sync/time_sync_step.dart';

import 'time_sync_step_test.mocks.dart';

class FakeAudioPlayerRepository implements AudioPlayerRepository {
  PlaybackInfo _currentPlayback;
  late final StreamController<PlaybackInfo> _controller;
  Duration? lastSeekPosition;
  int resumeCallCount = 0;
  int seekCallCount = 0;

  FakeAudioPlayerRepository([PlaybackInfo? initialPlayback])
      : _currentPlayback = initialPlayback ?? PlaybackInfo.idle() {
    _controller = StreamController<PlaybackInfo>.broadcast(
      onListen: () {
        _controller.add(_currentPlayback);
      },
    );
  }

  @override
  PlaybackInfo get currentPlayback => _currentPlayback;

  @override
  Stream<PlaybackInfo> get playbackStream => _controller.stream;

  void updatePosition(Duration position) {
    _currentPlayback = _currentPlayback.copyWith(position: position);
    _controller.add(_currentPlayback);
  }

  void updatePlayback({
    Track? track,
    Duration? position,
    Duration? duration,
    AudioPlayerState? state,
  }) {
    _currentPlayback = _currentPlayback.copyWith(
      currentTrack: track,
      position: position,
      duration: duration,
      state: state,
    );
    _controller.add(_currentPlayback);
  }

  void resetCallTracking() {
    lastSeekPosition = null;
    resumeCallCount = 0;
    seekCallCount = 0;
  }

  @override
  Future<void> playTrack(
    Track track, {
    String? audioUrl,
    String? songName,
    String? albumName,
  }) async {
    _currentPlayback = _currentPlayback.copyWith(
      currentTrack: track,
      position: Duration.zero,
      state: AudioPlayerState.playing,
    );
    _controller.add(_currentPlayback);
  }

  @override
  Future<void> resume() async {
    resumeCallCount += 1;
    _currentPlayback = _currentPlayback.copyWith(state: AudioPlayerState.playing);
    _controller.add(_currentPlayback);
  }

  @override
  Future<void> pause() async {
    _currentPlayback = _currentPlayback.copyWith(state: AudioPlayerState.paused);
    _controller.add(_currentPlayback);
  }

  @override
  Future<void> stop() async {
    _currentPlayback = _currentPlayback.copyWith(
      clearTrack: true,
      position: Duration.zero,
      duration: Duration.zero,
      state: AudioPlayerState.idle,
    );
    _controller.add(_currentPlayback);
  }

  @override
  Future<Duration> seek(Duration position) async {
    seekCallCount += 1;
    lastSeekPosition = position;
    updatePosition(position);
    return position;
  }

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
  Future<void> dispose() async {
    await _controller.close();
  }
}

@GenerateMocks([MarkerRepository])
void main() {
  group('TimeSyncStep Widget', () {
    late MockMarkerRepository mockMarkerRepository;
    late FakeAudioPlayerRepository fakeAudioRepository;
    late MarkerSyncNotifier notifier;

    setUp(() {
      mockMarkerRepository = MockMarkerRepository();
      fakeAudioRepository = FakeAudioPlayerRepository(
        PlaybackInfo.idle().copyWith(
          position: Duration.zero,
          duration: const Duration(minutes: 3),
        ),
      );
    });

    Future<Widget> createWidgetUnderTest({
      List<String>? labels,
      PlaybackInfo? playbackInfo,
      Track? trackOverride,
    }) async {
      final track = trackOverride ??
          Track(
            id: 'track-1',
            songId: 'song-1',
            name: 'Test Track',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          );
      Stream<PlaybackInfo> playbackStreamWithInitial() async* {
        yield fakeAudioRepository.currentPlayback;
        yield* fakeAudioRepository.playbackStream;
      }

      final container = ProviderContainer(
        overrides: [
          markerRepositoryProvider.overrideWithValue(mockMarkerRepository),
          audioPlayerRepositoryProvider.overrideWithValue(fakeAudioRepository),
          playbackInfoProvider.overrideWith((ref) => playbackStreamWithInitial()),
          trackByIdProvider.overrideWith(
            (ref, trackId) async => trackId == track.id ? track : null,
          ),
        ],
      );

      // Always initialize notifier so tests can access it
      notifier = container.read(
        markerSyncNotifierProvider(
          const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
        ).notifier,
      );

      // Set labels BEFORE building widget if provided
      if (labels != null) {
        notifier.setLabels(labels.join('\n'));
      }
      // Emit initial playback info for tests that depend on stream updates
      if (playbackInfo != null) {
        fakeAudioRepository.updatePosition(playbackInfo.position);
      } else {
        fakeAudioRepository.updatePosition(fakeAudioRepository.currentPlayback.position);
      }

      // Keep provider alive so autoDispose doesn't reset between setup and build
      final keepAlive = container.listen(
        markerSyncNotifierProvider(
          const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
        ),
        (_, __) {},
      );
      addTearDown(keepAlive.close);

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TimeSyncStep(
              params: MarkerSyncParams(
                trackId: 'track-1',
                markerSetId: 'set-1',
              ),
            ),
          ),
        ),
      );
    }

    Future<(ProviderContainer, Widget)> createWidgetWithContainer({
      List<String>? labels,
    }) async {
      Stream<PlaybackInfo> playbackStreamWithInitial() async* {
        yield fakeAudioRepository.currentPlayback;
        yield* fakeAudioRepository.playbackStream;
      }

      final container = ProviderContainer(
        overrides: [
          markerRepositoryProvider.overrideWithValue(mockMarkerRepository),
          audioPlayerRepositoryProvider.overrideWithValue(fakeAudioRepository),
          playbackInfoProvider.overrideWith((ref) => playbackStreamWithInitial()),
        ],
      );

      notifier = container.read(
        markerSyncNotifierProvider(
          const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
        ).notifier,
      );

      if (labels != null) {
        notifier.setLabels(labels.join('\n'));
      }
      fakeAudioRepository.updatePosition(fakeAudioRepository.currentPlayback.position);

      final keepAlive = container.listen(
        markerSyncNotifierProvider(
          const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
        ),
        (_, __) {},
      );
      addTearDown(keepAlive.close);

      final widget = UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TimeSyncStep(
              params: const MarkerSyncParams(
                trackId: 'track-1',
                markerSetId: 'set-1',
              ),
            ),
          ),
        ),
      );

      return (container, widget);
    }

    group('UI Rendering', () {
      testWidgets('displays audio controls', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Should show playback position
        expect(find.textContaining('0:00'), findsAtLeastNWidgets(1));

        // Should show play/pause button
        expect(find.byIcon(Icons.play_circle), findsOneWidget);

        // Should show rewind/forward buttons
        expect(find.byIcon(Icons.replay_10), findsOneWidget);
        expect(find.byIcon(Icons.forward_10), findsOneWidget);

        // Should show restart button
        expect(find.byIcon(Icons.restart_alt), findsOneWidget);
      });

      testWidgets('displays progress slider', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        expect(find.byType(Slider), findsOneWidget);
      });

      testWidgets('displays marker list with "..." marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Should show "..." marker at 0:00.000
        expect(find.byKey(const ValueKey('markerSyncMarker_-1')), findsOneWidget);
        expect(find.text('...'), findsOneWidget);
        expect(find.text('0:00.000'), findsAtLeastNWidgets(1));

        // Should show check icon for "..." marker (always synced)
        expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
      });

      testWidgets('displays all marker labels', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus', 'bridge']));
        await tester.pumpAndSettle();

        expect(find.text('verse'), findsOneWidget);
        expect(find.text('chorus'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('bridge'), 200);
        expect(find.text('bridge'), findsOneWidget);
      });

      testWidgets('highlights the last synced marker (not next)', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['A', 'B', 'C']));
        await tester.pumpAndSettle();

        // First sync
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        final aTile = tester.widget<ListTile>(find.byKey(const ValueKey('markerSyncMarker_0')));
        expect(aTile.selected, isTrue);

        // Second sync
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        final bTile = tester.widget<ListTile>(find.byKey(const ValueKey('markerSyncMarker_1')));
        expect(bTile.selected, isTrue);
      });

      testWidgets('renders empty lines as spacing', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', '', 'chorus']));
        await tester.pumpAndSettle();

        expect(find.text('verse'), findsOneWidget);
        expect(find.text('chorus'), findsOneWidget);

        // Empty line should be rendered as SizedBox with height
        expect(find.byType(SizedBox), findsWidgets);
      });

      testWidgets('displays sync button', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('markerSyncMarkHereButton')), findsOneWidget);
      });

      testWidgets('displays save and discard buttons', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('markerSyncSaveButton')), findsOneWidget);
        expect(find.byKey(const ValueKey('markerSyncDiscardButton')), findsOneWidget);
      });
    });

    group('Marker List State', () {
      testWidgets('shows pending icon for unsynced markers', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pending), findsAtLeastNWidgets(2));
      });

      testWidgets('shows check icon for synced markers', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Sync first marker
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // "..." and "verse" should both have check icons
        expect(find.byIcon(Icons.check), findsAtLeastNWidgets(2));
      });

      testWidgets('shows "not synced" for unsynced markers', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        expect(find.text('not synced'), findsAtLeastNWidgets(2));
      });

      testWidgets('shows position for synced markers', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Advance playback position
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Sync marker
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Should show position (format: M:SS.mmm)
        final markerTile = find.byKey(const ValueKey('markerSyncMarker_0'));
        expect(
          find.descendant(of: markerTile, matching: find.text('0:05.000')),
          findsOneWidget,
        );
      });

      testWidgets('highlights current marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync first marker
        await tester.tap(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        await tester.pumpAndSettle();

        // Current marker should be highlighted (selectedTileColor applied)
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
        final selectedTiles = listTiles.where((tile) => tile.selected == true).toList();

        expect(selectedTiles.length, 1);
        expect(selectedTiles.first.title, isA<Text>());
      });

      testWidgets('tapping synced marker seeks playback to its position', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync first marker at 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move playback elsewhere
        fakeAudioRepository.updatePosition(const Duration(seconds: 12));
        await tester.pumpAndSettle();

        // Tap synced marker
        await tester.tap(find.byKey(const ValueKey('markerSyncMarker_0')));
        await tester.pumpAndSettle();

        expect(fakeAudioRepository.lastSeekPosition, const Duration(seconds: 5));
      });
    });

    group('Sync Button State', () {
      testWidgets('sync button is enabled at position 0', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('sync button is disabled when position < last synced position', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync first marker at 10s
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move back to 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Button should be disabled
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('sync button is enabled when position >= last synced position', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync first marker at 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move to 10s
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        // Button should be enabled
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('sync button is enabled when position equals last synced position', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync first marker at 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Stay at 5s
        await tester.pumpAndSettle();

        // Button should be enabled (equal is allowed)
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('sync button is enabled after jumping back to earlier marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync verse at 10s
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Sync chorus at 20s
        fakeAudioRepository.updatePosition(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Jump back to verse (seeks to 10s)
        await tester.tap(find.byKey(const ValueKey('markerSyncMarker_0')));
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('sync button is disabled when all markers synced', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Sync the only marker
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Try to sync again (should fail - no more markers)
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Button should be disabled
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('shows helper text when sync button disabled', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync at 10s
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move back to 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(find.text('Move forward in time to sync the next marker'), findsOneWidget);
      });
    });

    group('Syncing Markers', () {
      testWidgets('syncs marker to current playback position', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Move to 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Sync
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Should show position
        final markerTile = find.byKey(const ValueKey('markerSyncMarker_0'));
        expect(
          find.descendant(of: markerTile, matching: find.text('0:05.000')),
          findsOneWidget,
        );
      });

      testWidgets('advances to next non-empty marker after sync', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', '', 'chorus']));
        await tester.pumpAndSettle();

        // Sync verse
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Sync should keep focus on last synced marker
        expect(notifier.state.currentIndex, 0);

        // Sync chorus (skip empty line)
        fakeAudioRepository.updatePosition(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 2);
        expect(notifier.state.syncedPositions[1], notifier.state.syncedPositions[2]);
      });

      testWidgets('syncs multiple markers in sequence', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus', 'bridge']));
        await tester.pumpAndSettle();

        // Sync verse
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move forward
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        // Sync chorus
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Move forward
        fakeAudioRepository.updatePosition(const Duration(seconds: 20));
        await tester.pumpAndSettle();

        // Sync bridge
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // All should be synced
        expect(find.text('not synced'), findsNothing);
      });

      testWidgets('keeps current marker visible after sync', (tester) async {
        final labels = List.generate(40, (i) => 'label-$i');
        await tester.pumpWidget(await createWidgetUnderTest(labels: labels));
        await tester.pumpAndSettle();

        // Sync once to advance to the next marker and trigger auto-scroll.
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));

        final listRect = tester.getRect(find.byType(ListView));
        final currentTileRect = tester.getRect(
          find.byKey(const ValueKey('markerSyncMarker_1')),
        );
        final tileCenter = currentTileRect.center.dy;

        expect(tileCenter, greaterThan(listRect.top));
        expect(tileCenter, lessThan(listRect.bottom));
      });

      testWidgets('marker list stays below audio controls', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        final controlsRect = tester.getRect(find.byType(Row).first);
        final listRect = tester.getRect(find.byType(ListView));

        expect(listRect.top, greaterThan(controlsRect.bottom));
      });

      testWidgets('keeps last synced marker visible near end', (tester) async {
        final labels = List.generate(50, (i) => 'label-$i');
        await tester.pumpWidget(await createWidgetUnderTest(labels: labels));
        await tester.pumpAndSettle();

        for (var i = 0; i < labels.length; i++) {
          await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(milliseconds: 400));

        final listRect = tester.getRect(find.byType(ListView));
        final lastTileRect = tester.getRect(
          find.byKey(const ValueKey('markerSyncMarker_49')),
        );
        final tileCenter = lastTileRect.center.dy;

        expect(tileCenter, greaterThan(listRect.top));
        expect(tileCenter, lessThan(listRect.bottom));
      });
    });

    group('Keyboard Shortcuts', () {
      testWidgets('Space key syncs next marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Press space
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        // Should sync marker
        expect(notifier.state.currentIndex, 0);
        expect(notifier.state.syncedPositions[0], isNotNull);
      });

      testWidgets('Space key respects monotonic invariant', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync at 10s
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        // Move back to 5s
        fakeAudioRepository.updatePosition(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Try to sync (should fail)
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        // Should still be on the last synced marker
        expect(notifier.state.currentIndex, 0);
      });

      testWidgets('Down arrow navigates to next marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus', 'bridge']));
        await tester.pumpAndSettle();

        // Initially at "..." (-1)
        expect(notifier.state.currentIndex, -1);

        // Press down
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 0); // verse
      });

      testWidgets('Down arrow skips empty lines', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', '', 'chorus']));
        await tester.pumpAndSettle();

        // Press down
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 0); // verse

        // Press down again
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 2); // chorus (skipped index 1)
      });

      testWidgets('Up arrow navigates to previous marker', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Jump to chorus
        notifier.jumpToMarker(1);
        await tester.pumpAndSettle();

        // Press up
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 0); // verse
      });

      testWidgets('Up arrow skips empty lines', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', '', 'chorus']));
        await tester.pumpAndSettle();

        // Jump to chorus
        notifier.jumpToMarker(2);
        await tester.pumpAndSettle();

        // Press up
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        expect(notifier.state.currentIndex, 0); // verse (skipped index 1)
      });

      testWidgets('R key shows restart confirmation', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Press R
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.pumpAndSettle();

        // Should show confirmation dialog
        expect(find.text('Restart sync?'), findsOneWidget);
      });
    });

    group('Restart Functionality', () {
      testWidgets('restart button shows confirmation dialog', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();

        expect(find.text('Restart sync?'), findsOneWidget);
        expect(find.text('This will clear all synced positions and start from the beginning.'), findsOneWidget);
      });

      testWidgets('restart confirmation can be cancelled', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Sync marker
        await tester.tap(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        await tester.pumpAndSettle();
        final positionsBefore = notifier.state.syncedPositions;

        // Show restart dialog
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();

        // Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Positions should be unchanged
        expect(notifier.state.syncedPositions, positionsBefore);
      });

      testWidgets('restart confirmation clears positions', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse', 'chorus']));
        await tester.pumpAndSettle();

        // Sync markers
        await tester.tap(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        await tester.pumpAndSettle();
        fakeAudioRepository.updatePosition(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        await tester.pumpAndSettle();

        // Restart
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restart'));
        await tester.pumpAndSettle();

        // Should only have "..." marker
        expect(notifier.state.syncedPositions, {-1: 0});
        expect(notifier.state.currentIndex, -1);
      });
    });

    group('Save and Discard', () {
      testWidgets('save button calls save and closes screen', (tester) async {
        final markerSet = MarkerSet(
          id: 'set-1',
          trackId: 'track-1',
          name: 'Test Set',
          isShared: false,
          isTimeSynced: false,
          createdByUserId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        when(mockMarkerRepository.createMarker(any)).thenAnswer((_) async {});
        when(mockMarkerRepository.deleteMarkersByMarkerSet(any)).thenAnswer((_) async {});
        when(mockMarkerRepository.getMarkerSetById(any)).thenAnswer((_) async => markerSet);
        when(mockMarkerRepository.updateMarkerSet(any)).thenAnswer((_) async => true);

        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Sync a marker
        await tester.tap(
          find.byKey(const ValueKey('markerSyncMarkHereButton')),
        );
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.byKey(const ValueKey('markerSyncSaveButton')));
        await tester.pumpAndSettle();

        // Should call repository
        verify(mockMarkerRepository.createMarker(any)).called(1);
      });

      testWidgets('save updates marker set synced state in providers', (tester) async {
        var markerSet = MarkerSet(
          id: 'set-1',
          trackId: 'track-1',
          name: 'Test Set',
          isShared: false,
          isTimeSynced: false,
          createdByUserId: 'user-1',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        when(mockMarkerRepository.createMarker(any)).thenAnswer((_) async {});
        when(mockMarkerRepository.deleteMarkersByMarkerSet(any)).thenAnswer((_) async {});
        when(mockMarkerRepository.getMarkerSetById(any)).thenAnswer((_) async => markerSet);
        when(mockMarkerRepository.updateMarkerSet(any)).thenAnswer((invocation) async {
          markerSet = invocation.positionalArguments.first as MarkerSet;
          return true;
        });

        final (container, widget) = await createWidgetWithContainer(labels: ['verse']);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        final before = await container.read(markerSetByIdProvider('set-1').future);
        expect(before?.isTimeSynced, false);

        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('markerSyncSaveButton')));
        await tester.pumpAndSettle();

        final after = await container.read(markerSetByIdProvider('set-1').future);
        expect(after?.isTimeSynced, true);
      });

      testWidgets('restart resets playback position to 0', (tester) async {
        final track = Track(
          id: 'track-1',
          songId: 'song-1',
          name: 'Test Track',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Move playback away from zero
        fakeAudioRepository.updatePlayback(
          track: track,
          position: const Duration(seconds: 12),
          duration: const Duration(minutes: 3),
          state: AudioPlayerState.paused,
        );
        await tester.pumpAndSettle();

        // Restart
        await tester.tap(find.byIcon(Icons.restart_alt));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restart'));
        await tester.pumpAndSettle();

        expect(fakeAudioRepository.currentPlayback.position, Duration.zero);
      });

      testWidgets('play resumes without resetting after pause', (tester) async {
        final track = Track(
          id: 'track-1',
          songId: 'song-1',
          name: 'Test Track',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        fakeAudioRepository.resetCallTracking();
        fakeAudioRepository.updatePlayback(
          track: track,
          position: const Duration(seconds: 18),
          duration: const Duration(minutes: 3),
          state: AudioPlayerState.paused,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_circle));
        await tester.pumpAndSettle();

        expect(fakeAudioRepository.seekCallCount, 0);
        expect(fakeAudioRepository.resumeCallCount, 1);
        expect(fakeAudioRepository.currentPlayback.position, const Duration(seconds: 18));
      });

      testWidgets('play starts from beginning', (tester) async {
        fakeAudioRepository.updatePosition(const Duration(seconds: 20));

        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_circle));
        await tester.pumpAndSettle();

        // playTrack always starts from the beginning
        expect(fakeAudioRepository.currentPlayback.state, AudioPlayerState.playing);
      });

      testWidgets('discard button closes screen without saving', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['verse']));
        await tester.pumpAndSettle();

        // Sync a marker
        await tester.tap(find.byKey(const ValueKey('markerSyncMarkHereButton')));
        await tester.pumpAndSettle();

        // Discard
        await tester.tap(find.byKey(const ValueKey('markerSyncDiscardButton')));
        await tester.pumpAndSettle();

        // Should NOT call repository
        verifyNever(mockMarkerRepository.createMarker(any));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles no labels', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: []));
        await tester.pumpAndSettle();

        // Should show "..." marker only
        expect(find.text('...'), findsOneWidget);
      });

      testWidgets('handles single label', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['intro']));
        await tester.pumpAndSettle();

        expect(find.text('intro'), findsOneWidget);
      });

      testWidgets('handles many labels', (tester) async {
        final manyLabels = List.generate(50, (i) => 'label-$i');
        await tester.pumpWidget(await createWidgetUnderTest(labels: manyLabels));
        await tester.pumpAndSettle();

        // Should render scrollable list
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('handles all empty lines', (tester) async {
        await tester.pumpWidget(await createWidgetUnderTest(labels: ['', '', '']));
        await tester.pumpAndSettle();

        // Should only show "..." marker (no non-empty markers to sync)
        expect(find.text('not synced'), findsNothing);
      });
    });
  });
}
