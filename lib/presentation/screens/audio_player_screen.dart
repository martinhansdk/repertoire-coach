import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/track_provider.dart';

/// Audio player screen for playing tracks from a song
class AudioPlayerScreen extends ConsumerWidget {
  final Song song;

  const AudioPlayerScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksBySongProvider(song.id));
    final playbackInfoAsync = ref.watch(playbackInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(song.title),
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(
              child: Text('No tracks available for this song'),
            );
          }

          return playbackInfoAsync.when(
            data: (playbackInfo) {
              return Column(
                children: [
                  // Track selector
                  Expanded(
                    child: ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack =
                            playbackInfo.currentTrack?.id == track.id;

                        return ListTile(
                          title: Text(track.name),
                          subtitle: track.filePath != null
                              ? const Text('Audio file available')
                              : const Text('No audio file'),
                          leading: Icon(
                            isCurrentTrack ? Icons.music_note : Icons.audiotrack,
                            color: isCurrentTrack ? Theme.of(context).colorScheme.primary : null,
                          ),
                          trailing: track.filePath != null
                              ? IconButton(
                                  icon: Icon(
                                    isCurrentTrack && playbackInfo.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: () {
                                    if (isCurrentTrack && playbackInfo.isPlaying) {
                                      ref
                                          .read(audioPlayerControlsProvider)
                                          .pause();
                                    } else {
                                      ref
                                          .read(audioPlayerControlsProvider)
                                          .playTrack(track);
                                    }
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                  ),

                  // Playback controls section
                  if (playbackInfo.hasTrack) ...[
                    const Divider(),
                    _buildPlaybackControls(context, ref, playbackInfo, tracks),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading tracks: $error'),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(
    BuildContext context,
    WidgetRef ref,
    playbackInfo,
    List<Track> tracks,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current track name
          Text(
            playbackInfo.currentTrack?.name ?? 'No track',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            children: [
              Slider(
                value: playbackInfo.progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  final newPosition = playbackInfo.duration * value;
                  ref.read(audioPlayerControlsProvider).seek(newPosition);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(playbackInfo.position)),
                    Text(_formatDuration(playbackInfo.duration)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Playback control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous track
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 36,
                onPressed: () {
                  final currentIndex = tracks.indexWhere(
                    (t) => t.id == playbackInfo.currentTrack?.id,
                  );
                  if (currentIndex > 0) {
                    ref
                        .read(audioPlayerControlsProvider)
                        .playTrack(tracks[currentIndex - 1]);
                  }
                },
              ),

              const SizedBox(width: 16),

              // Play/Pause button
              IconButton(
                icon: Icon(
                  playbackInfo.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                ),
                iconSize: 64,
                onPressed: () {
                  if (playbackInfo.isPlaying) {
                    ref.read(audioPlayerControlsProvider).pause();
                  } else {
                    ref.read(audioPlayerControlsProvider).resume();
                  }
                },
              ),

              const SizedBox(width: 16),

              // Next track
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 36,
                onPressed: () {
                  final currentIndex = tracks.indexWhere(
                    (t) => t.id == playbackInfo.currentTrack?.id,
                  );
                  if (currentIndex < tracks.length - 1) {
                    ref
                        .read(audioPlayerControlsProvider)
                        .playTrack(tracks[currentIndex + 1]);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Stop button
          TextButton.icon(
            onPressed: () {
              ref.read(audioPlayerControlsProvider).stop();
            },
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
