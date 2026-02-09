import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/selected_marker_set_provider.dart';
import 'package:repertoire_coach/presentation/screens/audio_player_screen.dart';
import 'package:repertoire_coach/presentation/widgets/marker_progress_bar.dart';

import '../providers/audio_player_provider_test.mocks.dart';

void main() {
  late MockAudioPlayerRepository mockAudioPlayerRepository;

  final tTrack1 = Track(id: 't1', songId: 's1', name: 'Track 1', filePath: '/path/to/track1.mp3', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tTrack2 = Track(id: 't2', songId: 's1', name: 'Track 2', filePath: '/path/to/track2.mp3', createdAt: DateTime.now(), updatedAt: DateTime.now());

  setUp(() {
    mockAudioPlayerRepository = MockAudioPlayerRepository();
    when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
    when(mockAudioPlayerRepository.playbackStream).thenAnswer((_) => Stream.value(PlaybackInfo.idle()));
    when(mockAudioPlayerRepository.resume()).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.pause()).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.stop()).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.seek(any)).thenAnswer((_) async => Duration.zero);
    when(mockAudioPlayerRepository.savePlaybackPosition()).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.loadPlaybackPosition(any)).thenAnswer((_) async => Duration.zero);
    when(mockAudioPlayerRepository.dispose()).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.playTrack(any)).thenAnswer((_) async {});
    when(mockAudioPlayerRepository.isLooping).thenReturn(false);
    when(mockAudioPlayerRepository.setLoopMode(any)).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({
    Stream<PlaybackInfo>? playbackInfoStream,
    Future<List<MarkerSet>>? markerSetsTrack1,
    Future<List<MarkerSet>>? markerSetsTrack2,
    Map<String, List<Marker>>? markersBySetId,
    Map<String, MarkerSet>? markerSetsById,
    String? selectedMarkerSetId,
  }) {
    return ProviderScope(
      overrides: [
        playbackInfoProvider.overrideWith((ref) => playbackInfoStream ?? Stream.value(PlaybackInfo.idle())),
        audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
        // Mock marker-related providers to prevent database access
        markerSetsByTrackProvider(('t1', 'local-user-1')).overrideWith(
          (ref) => markerSetsTrack1 ?? Future.value([]),
        ),
        markerSetsByTrackProvider(('t2', 'local-user-1')).overrideWith(
          (ref) => markerSetsTrack2 ?? Future.value([]),
        ),
        selectedMarkerSetProvider.overrideWithProvider(
          StateProvider<String?>((ref) => selectedMarkerSetId),
        ),
        markersByMarkerSetProvider('').overrideWith((ref) => Future.value([])),
        if (markersBySetId != null)
          ...markersBySetId.entries.map(
            (entry) => markersByMarkerSetProvider(entry.key)
                .overrideWith((ref) => Future.value(entry.value)),
          ),
        if (markerSetsById != null)
          ...markerSetsById.entries.map(
            (entry) => markerSetByIdProvider(entry.key)
                .overrideWith((ref) => Future.value(entry.value)),
          ),
      ],
      child: MaterialApp(
        home: AudioPlayerScreen(track: tTrack1, songTitle: 'Test Song', concertName: 'Test Concert'),
      ),
    );
  }

  testWidgets('shows loading indicator when playback info is loading', (tester) async {
    final streamController = StreamController<PlaybackInfo>();
    await tester.pumpWidget(createWidgetUnderTest(playbackInfoStream: streamController.stream));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    streamController.add(PlaybackInfo.idle());
    await tester.pump(const Duration(milliseconds: 200));

    await streamController.close();
  });

  testWidgets('displays track name in subtitle', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    expect(find.text('Track 1'), findsWidgets);
  });

  testWidgets('displays song title in appbar', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Test Song'), findsOneWidget);
  });

  testWidgets('forward 10 seconds button exists', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.forward_10), findsOneWidget);
  });

  testWidgets('replay 10 seconds button exists', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
  });

  testWidgets('playback controls are not in a scroll view', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('A-B loop button is present', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.paused,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.loop), findsOneWidget);
  });

  testWidgets('marker selector shares row with playback controls', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.paused,
    );
    final markerSet = MarkerSet(
      id: 'set-1',
      trackId: tTrack1.id,
      name: 'Set 1',
      isShared: false,
      isTimeSynced: true,
      createdByUserId: 'local-user-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        playbackInfoStream: Stream.value(playbackInfo),
        markerSetsTrack1: Future.value([markerSet]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final loopRect = tester.getRect(find.byIcon(Icons.loop));
    final playRect = tester.getRect(find.byIcon(Icons.play_circle_filled));
    expect((loopRect.center.dy - playRect.center.dy).abs(), lessThan(6));
  });

  testWidgets('stop button is not present', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.playing,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.stop), findsNothing);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('does not auto-play on initState', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    verifyNever(
      mockAudioPlayerRepository.playTrack(
        captureAny,
        songName: anyNamed('songName'),
        albumName: anyNamed('albumName'),
      ),
    );
  });

  testWidgets('stops playback when screen is disposed', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    verify(mockAudioPlayerRepository.stop()).called(1);
  });

  testWidgets('shows pause button when playing', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.playing,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final playPauseIcon = tester.widget<Icon>(find.byIcon(Icons.pause_circle_filled));
    expect(playPauseIcon, isNotNull);
  });

  testWidgets('tapping pause button calls pause', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.playing,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    await tester.pump();

    verify(mockAudioPlayerRepository.pause()).called(1);
  });

  testWidgets('clears markers when switching to track with no marker sets', (tester) async {
    final controller = StreamController<PlaybackInfo>();
    final markerSet1 = MarkerSet(
      id: 'set-1',
      trackId: tTrack1.id,
      name: 'Set 1',
      isShared: false,
      isTimeSynced: true,
      createdByUserId: 'local-user-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final marker1 = Marker(
      id: 'm1',
      markerSetId: markerSet1.id,
      label: 'Intro',
      positionMs: 1000,
      order: 1000,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        playbackInfoStream: controller.stream,
        markerSetsTrack1: Future.value([markerSet1]),
        markerSetsTrack2: Future.value([]),
        markerSetsById: {markerSet1.id: markerSet1},
        markersBySetId: {markerSet1.id: [marker1]},
      ),
    );

    controller.add(
      PlaybackInfo.idle().copyWith(
        currentTrack: tTrack1,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Intro'), findsOneWidget);
    expect(find.byType(MarkerProgressBar), findsOneWidget);

    controller.add(
      PlaybackInfo.idle().copyWith(
        currentTrack: tTrack2,
        duration: const Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Intro'), findsNothing);
    expect(find.byType(MarkerProgressBar), findsNothing);
    expect(find.text('No marker sets'), findsOneWidget);

    await controller.close();
  });
}
