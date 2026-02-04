import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/selected_marker_set_provider.dart';
import 'package:repertoire_coach/presentation/screens/audio_player_screen.dart';

import '../providers/audio_player_provider_test.mocks.dart';

void main() {
  late MockAudioPlayerRepository mockAudioPlayerRepository;

  final tTrack1 = Track(id: 't1', songId: 's1', name: 'Track 1', filePath: '/path/to/track1.mp3', createdAt: DateTime.now(), updatedAt: DateTime.now());

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
  }) {
    return ProviderScope(
      overrides: [
        playbackInfoProvider.overrideWith((ref) => playbackInfoStream ?? Stream.value(PlaybackInfo.idle())),
        audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
        // Mock marker-related providers to prevent database access
        markerSetsByTrackProvider(('t1', 'local-user-1')).overrideWith((ref) => Future.value([])),
        selectedMarkerSetProvider.overrideWith((ref) => SelectedMarkerSetNotifier()),
        markersByMarkerSetProvider('').overrideWith((ref) => Future.value([])),
      ],
      child: MaterialApp(
        home: AudioPlayerScreen(track: tTrack1, songTitle: 'Test Song'),
      ),
    );
  }

  testWidgets('shows loading indicator when playback info is loading', (tester) async {
    final streamController = StreamController<PlaybackInfo>();
    await tester.pumpWidget(createWidgetUnderTest(playbackInfoStream: streamController.stream));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    streamController.add(PlaybackInfo.idle());
    await tester.pumpAndSettle();

    await streamController.close();
  });

  testWidgets('displays track name in subtitle', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('loop button is present and shows repeat_one initially', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.paused,
      isTrackLooping: false,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.repeat_one), findsOneWidget);
  });

  testWidgets('loop button shows repeat icon when looping', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.paused,
      isTrackLooping: true,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.repeat), findsOneWidget);
  });

  testWidgets('auto-play calls playTrack on initState', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    verify(mockAudioPlayerRepository.playTrack(captureAny)).called(1);
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
}
