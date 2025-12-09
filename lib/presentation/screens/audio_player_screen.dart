import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/marker_provider.dart';
import '../providers/selected_marker_set_provider.dart';
import '../providers/track_provider.dart';
import '../widgets/loop_control_buttons.dart';
import '../widgets/marker_list.dart';
import '../widgets/marker_progress_bar.dart';
import '../widgets/marker_set_selector.dart';
import 'marker_manager_screen.dart';

/// Hardcoded user ID for local-first mode
const String _currentUserId = 'local-user-1';

/// Audio player screen for playing tracks from a song
class AudioPlayerScreen extends ConsumerStatefulWidget {
  final Song song;

  const AudioPlayerScreen({super.key, required this.song});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();

    // Stop playback when switching to a different song
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playbackInfo = ref.read(audioPlayerRepositoryProvider).currentPlayback;
      final currentTrack = playbackInfo.currentTrack;

      if (currentTrack != null && currentTrack.songId != widget.song.id) {
        // Currently playing track is from a different song, stop it
        ref.read(audioPlayerControlsProvider).stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksBySongProvider(widget.song.id));
    final playbackInfoAsync = ref.watch(playbackInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
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
              // Check if the currently playing track belongs to this song
              final isPlayingTrackFromThisSong =
                  playbackInfo.currentTrack?.songId == widget.song.id;

              return Column(
                children: [
                  // Track selector
                  Expanded(
                    child: ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack = isPlayingTrackFromThisSong &&
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Markers button
                              IconButton(
                                icon: const Icon(Icons.bookmarks),
                                tooltip: 'Manage Markers',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MarkerManagerScreen(
                                        trackId: track.id,
                                        trackName: track.name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Play/pause button
                              if (track.filePath != null)
                                IconButton(
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
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Playback controls section (only show if playing a track from this song)
                  if (playbackInfo.hasTrack && isPlayingTrackFromThisSong) ...[
                    const Divider(),
                    Flexible(
                      child: _buildPlaybackControls(playbackInfo, tracks),
                    ),
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
    playbackInfo,
    List<Track> tracks,
  ) {
    final currentTrack = playbackInfo.currentTrack;
    if (currentTrack == null) return const SizedBox.shrink();

    final markerSetsAsync = ref.watch(
      markerSetsByTrackProvider((currentTrack.id, _currentUserId)),
    );

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current track name
            Text(
              currentTrack.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Marker set selector
            markerSetsAsync.when(
              data: (markerSets) {
                if (markerSets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: MarkerSetSelector(
                      markerSets: const [],
                      onManageMarkers: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarkerManagerScreen(
                              trackId: currentTrack.id,
                              trackName: currentTrack.name,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: MarkerSetSelector(
                    markerSets: markerSets,
                    onManageMarkers: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarkerManagerScreen(
                            trackId: currentTrack.id,
                            trackName: currentTrack.name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Progress bar with markers
            _buildProgressBar(currentTrack, playbackInfo),

            const SizedBox(height: 8),

            // Time display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(playbackInfo.position)),
                  Text(_formatDuration(playbackInfo.duration)),
                ],
              ),
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

                const SizedBox(width: 8),

                // Rewind 10 seconds
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  iconSize: 36,
                  onPressed: () {
                    final currentPosition = playbackInfo.position;
                    final newPosition = currentPosition - const Duration(seconds: 10);
                    final seekPosition = newPosition < Duration.zero
                        ? Duration.zero
                        : newPosition;
                    ref.read(audioPlayerControlsProvider).seek(seekPosition);
                  },
                ),

                const SizedBox(width: 8),

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

            const SizedBox(height: 16),

            // Marker list and loop controls
            _buildMarkerSection(currentTrack, playbackInfo),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Track track, playbackInfo) {
    final selectedMarkerSetId = ref.watch(selectedMarkerSetProvider).selectedMarkerSetId;

    if (selectedMarkerSetId == null) {
      // No marker set selected, use simple slider
      final double sliderValue = _isDraggingSlider
          ? _dragValue
          : playbackInfo.progress.clamp(0.0, 1.0);

      return Slider(
        value: sliderValue,
        onChangeStart: (value) {
          setState(() {
            _isDraggingSlider = true;
            _dragValue = value;
          });
        },
        onChanged: (value) {
          setState(() {
            _dragValue = value;
          });
        },
        onChangeEnd: (value) {
          final newPosition = playbackInfo.duration * value;
          ref.read(audioPlayerControlsProvider).seek(newPosition);
          setState(() {
            _isDraggingSlider = false;
          });
        },
      );
    }

    final markersAsync = ref.watch(markersByMarkerSetProvider(selectedMarkerSetId));

    return markersAsync.when(
      data: (markers) {
        final loopRange = playbackInfo.loopRange;
        return MarkerProgressBar(
          position: playbackInfo.position,
          duration: playbackInfo.duration,
          markers: markers,
          loopStart: loopRange?.startPosition,
          loopEnd: loopRange?.endPosition,
          onSeek: (position) {
            ref.read(audioPlayerControlsProvider).seek(position);
          },
        );
      },
      loading: () {
        final double sliderValue = _isDraggingSlider
            ? _dragValue
            : playbackInfo.progress.clamp(0.0, 1.0);
        return Slider(
          value: sliderValue,
          onChangeStart: (value) {
            setState(() {
              _isDraggingSlider = true;
              _dragValue = value;
            });
          },
          onChanged: (value) {
            setState(() {
              _dragValue = value;
            });
          },
          onChangeEnd: (value) {
            final newPosition = playbackInfo.duration * value;
            ref.read(audioPlayerControlsProvider).seek(newPosition);
            setState(() {
              _isDraggingSlider = false;
            });
          },
        );
      },
      error: (_, __) {
        final double sliderValue = _isDraggingSlider
            ? _dragValue
            : playbackInfo.progress.clamp(0.0, 1.0);
        return Slider(
          value: sliderValue,
          onChangeStart: (value) {
            setState(() {
              _isDraggingSlider = true;
              _dragValue = value;
            });
          },
          onChanged: (value) {
            setState(() {
              _dragValue = value;
            });
          },
          onChangeEnd: (value) {
            final newPosition = playbackInfo.duration * value;
            ref.read(audioPlayerControlsProvider).seek(newPosition);
            setState(() {
              _isDraggingSlider = false;
            });
          },
        );
      },
    );
  }

  Widget _buildMarkerSection(Track track, playbackInfo) {
    final selectedMarkerSetId = ref.watch(selectedMarkerSetProvider).selectedMarkerSetId;

    if (selectedMarkerSetId == null) {
      return const SizedBox.shrink();
    }

    final markersAsync = ref.watch(markersByMarkerSetProvider(selectedMarkerSetId));

    return markersAsync.when(
      data: (markers) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loop control buttons
            LoopControlButtons(markers: markers),

            const SizedBox(height: 8),

            // Marker list
            if (markers.isNotEmpty) ...[
              Text(
                'Markers',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              MarkerList(
                markers: markers,
                currentPosition: playbackInfo.position,
                onMarkerTap: (position) {
                  ref.read(audioPlayerControlsProvider).seek(position);
                },
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error loading markers: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
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
