import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/marker_provider.dart';
import '../providers/selected_marker_set_provider.dart';
import '../widgets/marker_list.dart';
import '../widgets/marker_progress_bar.dart';
import '../widgets/marker_set_selector.dart';
import 'marker_manager_screen.dart';

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
  late final AudioPlayerControls _audioControls;

  @override
  void initState() {
    super.initState();
    _audioControls = ref.read(audioPlayerControlsProvider);
    final playbackInfo = ref.read(currentPlaybackProvider);
    if (playbackInfo.currentTrack?.id != null &&
        playbackInfo.currentTrack?.id != widget.track.id) {
      _audioControls.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _audioControls.stop();
    }
  }

  @override
  void dispose() {
    _audioControls.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackInfoAsync = ref.watch(playbackInfoProvider);
    ref.listen<AsyncValue<PlaybackInfo>>(
      playbackInfoProvider,
      (previous, next) {
        final previousTrack = previous?.value?.currentTrack ?? widget.track;
        final nextTrack = next.value?.currentTrack ?? widget.track;
        if (previousTrack.id != nextTrack.id) {
          ref.read(selectedMarkerSetProvider.notifier).state = null;
        }
      },
    );

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
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) {
      return const Center(child: Text('Please sign in to view marker sets.'));
    }

    final markerSetsAsync = ref.watch(
      markerSetsByTrackProvider((currentTrack.id, userId)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  return Row(
                    children: [
                      IconButton(
                    icon: const Icon(Icons.replay_10),
                    iconSize: 28,
                    onPressed: () {
                      final currentPosition = playbackInfo.position;
                      final newPosition = currentPosition - const Duration(seconds: 10);
                      final seekPosition = newPosition < Duration.zero
                          ? Duration.zero
                          : newPosition;
                      ref.read(audioPlayerControlsProvider).seek(seekPosition);
                    },
                  ),
                      IconButton(
                    icon: Icon(
                      playbackInfo.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    ),
                    iconSize: 48,
                    onPressed: () {
                      final isDifferentTrack =
                          playbackInfo.currentTrack?.id != widget.track.id;
                      if (playbackInfo.isPlaying) {
                        _audioControls.pause();
                      } else if (isDifferentTrack ||
                          playbackInfo.state == AudioPlayerState.idle) {
                        _audioControls.playTrack(
                          widget.track,
                          songName: widget.songTitle,
                          albumName: widget.concertName,
                        );
                      } else {
                        _audioControls.resume();
                      }
                    },
                  ),
                      IconButton(
                    icon: const Icon(Icons.forward_10),
                    iconSize: 28,
                    onPressed: () {
                      final currentPosition = playbackInfo.position;
                      final newPosition = currentPosition + const Duration(seconds: 10);
                      final seekPosition = newPosition > playbackInfo.duration
                          ? playbackInfo.duration
                          : newPosition;
                      ref.read(audioPlayerControlsProvider).seek(seekPosition);
                    },
                  ),
                      const SizedBox(width: 4),
                      IconButton(
                    icon: const Icon(Icons.loop),
                    tooltip: 'A-B Loop (coming soon)',
                    onPressed: () {},
                  ),
                      const SizedBox(width: 8),
                      Expanded(
                    child: markerSetsAsync.when(
                      data: (markerSets) {
                        return MarkerSetSelector(
                          markerSets: markerSets,
                          compact: isCompact,
                          onManageMarkers: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MarkerManagerScreen(
                                  trackId: currentTrack.id,
                                  trackName: currentTrack.name,
                                  songTitle: widget.songTitle,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 6),

              // Progress bar with markers
              _buildProgressBar(currentTrack, playbackInfo),

              const SizedBox(height: 2),

              // Time display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(playbackInfo.position)),
                  Text(_formatDuration(playbackInfo.duration)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildMarkerSection(currentTrack, playbackInfo),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(Track track, playbackInfo) {
    final selectedMarkerSetId = ref.watch(selectedMarkerSetProvider);

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

    final markerSetAsync = ref.watch(markerSetByIdProvider(selectedMarkerSetId));
    final markersAsync = ref.watch(markersByMarkerSetProvider(selectedMarkerSetId));

    return markerSetAsync.when(
      data: (markerSet) {
        if (markerSet == null || !markerSet.isTimeSynced) {
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

        return markersAsync.when(
          data: (markers) {
            final loopRange = playbackInfo.loopRange;
            final progressMarkers =
                markers.where((marker) => marker.label.trim().isNotEmpty).toList();
            return MarkerProgressBar(
              position: playbackInfo.position,
              duration: playbackInfo.duration,
              markers: progressMarkers,
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
    final selectedMarkerSetId = ref.watch(selectedMarkerSetProvider);

    if (selectedMarkerSetId == null) {
      return const SizedBox.shrink();
    }

    final markerSetAsync = ref.watch(markerSetByIdProvider(selectedMarkerSetId));
    final markersAsync = ref.watch(markersByMarkerSetProvider(selectedMarkerSetId));

    return markerSetAsync.when(
      data: (markerSet) {
        if (markerSet == null) {
          return const SizedBox.shrink();
        }

        return markersAsync.when(
          data: (markers) {
            final visibleMarkers =
                markers.where((marker) => marker.label.trim().isNotEmpty).toList();

            return MarkerList(
              markers: visibleMarkers,
              currentPosition: playbackInfo.position,
              trackDuration: playbackInfo.duration,
              showPositions: markerSet.isTimeSynced,
              onMarkerTap: markerSet.isTimeSynced
                  ? (position) {
                      ref.read(audioPlayerControlsProvider).seek(position);
                    }
                  : null,
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
            'Error loading marker set: $error',
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
