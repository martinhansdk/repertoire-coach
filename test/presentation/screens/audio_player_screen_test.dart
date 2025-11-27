import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';
import 'package:repertoire_coach/domain/entities/playback_info.dart';
import 'package:repertoire_coach/domain/entities/audio_player_state.dart';
import 'package:repertoire_coach/domain/repositories/audio_player_repository.dart';
import 'package:repertoire_coach/presentation/providers/audio_player_provider.dart';
import 'package:repertoire_coach/presentation/providers/track_provider.dart';
import 'package:repertoire_coach/presentation/screens/audio_player_screen.dart';

import 'audio_player_screen_test.mocks.dart';

@GenerateMocks([AudioPlayerRepository])
void main() {
  late MockAudioPlayerRepository mockAudioPlayerRepository;
  late Song testSong1;
  late Track testTrack1;
  late Track testTrack2;
  late Track testTrack3;

  setUp(() {
    mockAudioPlayerRepository = MockAudioPlayerRepository();

    testSong1 = Song(
      id: 'song-1',
      title: 'Test Song 1',
      concertId: 'concert-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testTrack1 = Track(
      id: 'track-1',
      songId: 'song-1',
      name: 'Track 1',
      filePath: '/path/to/track1.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testTrack2 = Track(
      id: 'track-2',
      songId: 'song-1',
      name: 'Track 2',
      filePath: '/path/to/track2.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testTrack3 = Track(
      id: 'track-3',
      songId: 'song-2',
      name: 'Track 3',
      filePath: '/path/to/track3.mp3',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  Widget createTestWidget(Song song, List<Track> tracks) {
    return ProviderScope(
      overrides: [
        audioPlayerRepositoryProvider.overrideWithValue(mockAudioPlayerRepository),
        tracksBySongProvider(song.id).overrideWith(
          (ref) => Future.value(tracks),
        ),
      ],
      child: MaterialApp(
        home: AudioPlayerScreen(song: song),
      ),
    );
  }

  group('AudioPlayerScreen - Song Switching', () {
    testWidgets('stops playback when opening different song', (tester) async {
      // Setup: Track from song 2 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack3, // From song 2
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(playbackInfo);
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );
      when(mockAudioPlayerRepository.stop()).thenAnswer((_) async {});

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: Stop should be called because track 3 is from song 2, not song 1
      verify(mockAudioPlayerRepository.stop()).called(1);
    });

    testWidgets('does not stop playback when opening same song', (tester) async {
      // Setup: Track from song 1 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack1, // From song 1
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(playbackInfo);
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: Stop should NOT be called because track 1 is from song 1
      verifyNever(mockAudioPlayerRepository.stop());
    });

    testWidgets('hides playback controls when playing track from different song', (tester) async {
      // Setup: Track from song 2 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack3, // From song 2
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );
      when(mockAudioPlayerRepository.stop()).thenAnswer((_) async {});

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: Playback controls should not be visible
      expect(find.byIcon(Icons.pause_circle_filled), findsNothing);
      expect(find.byIcon(Icons.play_circle_filled), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('shows playback controls when playing track from same song', (tester) async {
      // Setup: Track from song 1 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack1, // From song 1
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(playbackInfo);
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: Playback controls should be visible
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('highlights current track only if from same song', (tester) async {
      // Setup: Track from song 1 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack1, // From song 1
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(playbackInfo);
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: Track 1 should show music_note icon (highlighted)
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      // Track 2 should show audiotrack icon (not highlighted)
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    });

    testWidgets('does not highlight tracks when playing from different song', (tester) async {
      // Setup: Track from song 2 is currently playing
      final playbackInfo = PlaybackInfo(
        state: AudioPlayerState.playing,
        currentTrack: testTrack3, // From song 2
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
      );

      when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(playbackInfo),
      );
      when(mockAudioPlayerRepository.stop()).thenAnswer((_) async {});

      // Act: Open audio player for song 1
      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      // Assert: No tracks should show music_note icon (highlighted)
      expect(find.byIcon(Icons.music_note), findsNothing);
      // Both tracks should show audiotrack icon (not highlighted)
      expect(find.byIcon(Icons.audiotrack), findsNWidgets(2));
    });
  });

  group('AudioPlayerScreen - Basic UI', () {
    testWidgets('displays song title in app bar', (tester) async {
      when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(PlaybackInfo.idle()),
      );

      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1]));
      await tester.pumpAndSettle();

      expect(find.text('Test Song 1'), findsOneWidget);
    });

    testWidgets('displays empty state when no tracks', (tester) async {
      when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(PlaybackInfo.idle()),
      );

      await tester.pumpWidget(createTestWidget(testSong1, []));
      await tester.pumpAndSettle();

      expect(find.text('No tracks available for this song'), findsOneWidget);
    });

    testWidgets('displays all tracks in list', (tester) async {
      when(mockAudioPlayerRepository.currentPlayback).thenReturn(PlaybackInfo.idle());
      when(mockAudioPlayerRepository.playbackStream).thenAnswer(
        (_) => Stream.value(PlaybackInfo.idle()),
      );

      await tester.pumpWidget(createTestWidget(testSong1, [testTrack1, testTrack2]));
      await tester.pumpAndSettle();

      expect(find.text('Track 1'), findsOneWidget);
      expect(find.text('Track 2'), findsOneWidget);
    });
  });
}
