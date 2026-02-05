import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/track.dart';
import '../providers/audio_player_provider.dart';
import '../providers/marker_provider.dart';
import '../providers/selected_marker_set_provider.dart';
import '../widgets/loop_control_buttons.dart';
import '../widgets/marker_list.dart';
import '../widgets/marker_progress_bar.dart';
import '../widgets/marker_set_selector.dart';
import 'marker_manager_screen.dart';

/// Hardcoded user ID for local-first mode
const String _currentUserId = 'local-user-1';

/// Audio player screen for playing a single track
class AudioPlayerScreen extends ConsumerStatefulWidget {
  final Track track;
  final String songTitle;
  final String concertName;

  const AudioPlayerScreen({super.key, required this.track, required this.songTitle, required this.concertName});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(audioPlayerControlsProvider).playTrack(
          widget.track,
          songName: widget.songTitle,
          albumName: widget.concertName,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playbackInfoAsync = ref.watch(playbackInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.songTitle,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.track.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: playbackInfoAsync.when(
        data: (playbackInfo) {
          return _buildPlaybackControls(playbackInfo);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(playbackInfo) {
    final currentTrack = playbackInfo.currentTrack ?? widget.track;

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

                const SizedBox(width: 8),

                // Forward 10 seconds
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  iconSize: 36,
                  onPressed: () {
                    final currentPosition = playbackInfo.position;
                    final newPosition = currentPosition + const Duration(seconds: 10);
                    final seekPosition = newPosition > playbackInfo.duration
                        ? playbackInfo.duration
                        : newPosition;
                    ref.read(audioPlayerControlsProvider).seek(seekPosition);
                  },
                ),

                const SizedBox(width: 8),

                // Loop toggle button
                IconButton(
                  icon: Icon(
                    playbackInfo.isTrackLooping ? Icons.repeat : Icons.repeat_one,
                  ),
                  tooltip: playbackInfo.isTrackLooping ? 'Loop on' : 'Loop off',
                  color: playbackInfo.isTrackLooping
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  onPressed: () {
                    ref.read(audioPlayerControlsProvider).toggleTrackLoop();
                  },
                ),
              ],
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
