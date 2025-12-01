import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/track_provider.dart';
import 'package:repertoire_coach/presentation/screens/audio_player_screen.dart';

import '../providers/audio_player_provider_test.mocks.dart';

void main() {
  late MockAudioPlayerRepository mockAudioPlayerRepository;

  final tSong = Song(id: 's1', concertId: 'c1', title: 'Test Song', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tTrack1 = Track(id: 't1', songId: 's1', name: 'Track 1', filePath: '/path/to/track1.mp3', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tTrack2 = Track(id: 't2', songId: 's1', name: 'Track 2', filePath: '/path/to/track2.mp3', createdAt: DateTime.now(), updatedAt: DateTime.now());
  final tTracks = [tTrack1, tTrack2];

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
  });

  Widget createWidgetUnderTest({
    Future<List<Track>>? tracksFuture,
    Stream<PlaybackInfo>? playbackInfoStream,
  }) {
    return ProviderScope(
      overrides: [
        tracksBySongProvider(tSong.id).overrideWith((ref) => tracksFuture ?? Future.value(tTracks)),
        playbackInfoProvider.overrideWith((ref) => playbackInfoStream ?? Stream.value(PlaybackInfo.idle())),
        audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
      ],
      child: MaterialApp(
        home: AudioPlayerScreen(song: tSong),
      ),
    );
  }

  testWidgets('shows loading indicator when tracks are loading', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(tracksFuture: Future.delayed(const Duration(seconds: 1), () => [])));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows empty state when there are no tracks', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(tracksFuture: Future.value([])));
    await tester.pumpAndSettle();
    expect(find.text('No tracks available for this song'), findsOneWidget);
  });

  testWidgets('displays list of tracks', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    expect(find.text('Track 1'), findsOneWidget);
    expect(find.text('Track 2'), findsOneWidget);
  });

  testWidgets('tapping play button calls playTrack', (tester) async {
    when(mockAudioPlayerRepository.playTrack(any)).thenAnswer((_) async {});
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pump();

    final verification = verify(mockAudioPlayerRepository.playTrack(captureAny));
    expect(verification.captured.single, tTrack1);
    verification.called(1);
  });

  testWidgets('shows pause button when playing', (tester) async {
    final playbackInfo = PlaybackInfo.idle().copyWith(
      currentTrack: tTrack1,
      state: AudioPlayerState.playing,
    );
    await tester.pumpWidget(createWidgetUnderTest(
      playbackInfoStream: Stream.value(playbackInfo),
    ));
    await tester.pumpAndSettle();

    final playPauseIcon = tester.widget<Icon>(find.byIcon(Icons.pause));
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
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    verify(mockAudioPlayerRepository.pause()).called(1);
  });
}
