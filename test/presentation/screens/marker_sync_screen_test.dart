import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_sync_provider.dart';
import 'package:repertoire_coach/presentation/screens/marker_sync/marker_sync_screen.dart';

import '../providers/audio_player_provider_test.mocks.dart';
import '../providers/marker_sync_provider_test.mocks.dart';

void main() {
  late MockAudioPlayerRepository mockAudioPlayerRepository;
  late MockMarkerRepository mockMarkerRepository;

  setUp(() {
    mockAudioPlayerRepository = MockAudioPlayerRepository();
    mockMarkerRepository = MockMarkerRepository();
    when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
    when(mockAudioPlayerRepository.playbackStream)
        .thenAnswer((_) => Stream.value(PlaybackInfo.idle()));
    when(mockAudioPlayerRepository.stop()).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({ProviderContainer? container}) {
    final scopeContainer = container ??
        ProviderContainer(
          overrides: [
            audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
            playbackInfoProvider.overrideWith((ref) => Stream.value(PlaybackInfo.idle())),
            markerRepositoryProvider.overrideWithValue(mockMarkerRepository),
          ],
        );
    return UncontrolledProviderScope(
      container: scopeContainer,
      child: const MaterialApp(
        home: MarkerSyncScreen(
          trackId: 'track-1',
          markerSetId: 'set-1',
        ),
      ),
    );
  }

  testWidgets('stops playback when screen is disposed', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    verify(mockAudioPlayerRepository.stop()).called(1);
  });

  testWidgets('shows restart sync button during time sync', (tester) async {
    final container = ProviderContainer(
      overrides: [
        audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
        playbackInfoProvider.overrideWith((ref) => Stream.value(PlaybackInfo.idle())),
        markerRepositoryProvider.overrideWithValue(mockMarkerRepository),
      ],
    );
    container
        .read(
          markerSyncNotifierProvider(
            const MarkerSyncParams(trackId: 'track-1', markerSetId: 'set-1'),
          ).notifier,
        )
        .setLabels('verse');

    await tester.pumpWidget(createWidgetUnderTest(container: container));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restart_alt), findsWidgets);
  });
}
