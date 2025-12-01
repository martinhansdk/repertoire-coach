import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';

import 'audio_player_provider_test.mocks.dart';

@GenerateMocks([AudioPlayerRepository])
void main() {
  group('Audio Player Providers', () {
    late MockAudioPlayerRepository mockRepository;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockAudioPlayerRepository();
      container = ProviderContainer(
        overrides: [
          audioPlayerRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('audioPlayerRepositoryProvider returns AudioPlayerRepository', () {
      expect(container.read(audioPlayerRepositoryProvider), isA<AudioPlayerRepository>());
    });

    group('playbackInfoProvider', () {
      test('emits PlaybackInfo from repository stream', () async {
        final playbackInfo = PlaybackInfo.idle();
        final streamController = StreamController<PlaybackInfo>();
        when(mockRepository.playbackStream).thenAnswer((_) => streamController.stream);

        final values = <AsyncValue<PlaybackInfo>>[];
        container.listen(playbackInfoProvider, (previous, next) {
          values.add(next);
        }, fireImmediately: true);

        // The provider starts in a loading state
        expect(values, [isA<AsyncLoading<PlaybackInfo>>()]);
        
        streamController.add(playbackInfo);

        // Wait for the stream to emit
        await container.pump();

        expect(values.last, isA<AsyncData<PlaybackInfo>>());
        expect(values.last.value, playbackInfo);

        streamController.close();
      });
    });

    group('currentPlaybackProvider', () {
      test('returns current playback info from repository', () {
        final playbackInfo = PlaybackInfo.idle();
        when(mockRepository.currentPlayback).thenReturn(playbackInfo);

        final result = container.read(currentPlaybackProvider);
        expect(result, playbackInfo);
      });
    });

    group('AudioPlayerControls', () {
      late AudioPlayerControls controls;

      setUp(() {
        controls = container.read(audioPlayerControlsProvider);
      });

      test('playTrack calls repository', () async {
        final track = Track(id: 't1', songId: 's1', name: 'Track 1', createdAt: DateTime.now(), updatedAt: DateTime.now());
        await controls.playTrack(track);
        verify(mockRepository.playTrack(track, startPosition: Duration.zero)).called(1);
      });

      test('resume calls repository', () async {
        await controls.resume();
        verify(mockRepository.resume()).called(1);
      });

      test('pause calls repository', () async {
        await controls.pause();
        verify(mockRepository.pause()).called(1);
      });

      test('stop calls repository', () async {
        await controls.stop();
        verify(mockRepository.stop()).called(1);
      });

      test('seek calls repository', () async {
        const position = Duration(seconds: 10);
        when(mockRepository.seek(position)).thenAnswer((_) async => position);
        await controls.seek(position);
        verify(mockRepository.seek(position)).called(1);
      });

      test('togglePlayPause calls pause when playing', () async {
        when(mockRepository.currentPlayback).thenReturn(PlaybackInfo.idle().copyWith(state: AudioPlayerState.playing));
        await controls.togglePlayPause();
        verify(mockRepository.pause()).called(1);
        verifyNever(mockRepository.resume());
      });

      test('togglePlayPause calls resume when not playing', () async {
        when(mockRepository.currentPlayback).thenReturn(PlaybackInfo.idle().copyWith(state: AudioPlayerState.paused));
        await controls.togglePlayPause();
        verify(mockRepository.resume()).called(1);
        verifyNever(mockRepository.pause());
      });

      test('savePosition calls repository', () async {
        await controls.savePosition();
        verify(mockRepository.savePlaybackPosition()).called(1);
      });

      test('loadPosition calls repository', () async {
        const trackId = 't1';
        when(mockRepository.loadPlaybackPosition(trackId)).thenAnswer((_) async => Duration.zero);
        await controls.loadPosition(trackId);
        verify(mockRepository.loadPlaybackPosition(trackId)).called(1);
      });
    });
  });
}
