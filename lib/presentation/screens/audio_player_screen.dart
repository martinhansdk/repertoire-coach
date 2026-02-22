import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/screen_awake_service.dart';
import '../../domain/entities/audio_player_state.dart';
import '../../domain/entities/playback_info.dart';
import '../../domain/entities/track.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/favorite_track_provider.dart';
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
  bool _isKeepingScreenAwake = false;

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
    if (_isKeepingScreenAwake) {
      ScreenAwakeService.setEnabled(false);
      _isKeepingScreenAwake = false;
    }
    _audioControls.stop();
    super.dispose();
  }

  Future<void> _setKeepScreenAwake(bool enabled) async {
    if (_isKeepingScreenAwake == enabled) return;
    _isKeepingScreenAwake = enabled;
    await ScreenAwakeService.setEnabled(enabled);
  }

  Future<void> _seekBackward10Seconds(PlaybackInfo playbackInfo) async {
    final currentPosition = playbackInfo.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    final seekPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    await _audioControls.seek(seekPosition);
  }

  Future<void> _seekForward10Seconds(PlaybackInfo playbackInfo) async {
    final currentPosition = playbackInfo.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    final seekPosition = newPosition > playbackInfo.duration
        ? playbackInfo.duration
        : newPosition;
    await _audioControls.seek(seekPosition);
  }

  Future<void> _togglePlayPause(PlaybackInfo playbackInfo) async {
    final isDifferentTrack = playbackInfo.currentTrack?.id != widget.track.id;
    if (playbackInfo.isPlaying) {
      await _audioControls.pause();
      return;
    }
    if (isDifferentTrack || playbackInfo.state == AudioPlayerState.idle) {
      await _audioControls.playTrack(
        widget.track,
        songName: widget.songTitle,
        albumName: widget.concertName,
      );
      return;
    }
    await _audioControls.resume();
  }

  Widget _buildKeyboardShortcuts(PlaybackInfo playbackInfo, Widget child) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaPlayPause): const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaRewind): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyL): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackNext): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaFastForward): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyR): const _ToggleLoopIntent(),
      },
      child: Actions(
        actions: {
          _TogglePlayPauseIntent: CallbackAction<_TogglePlayPauseIntent>(
            onInvoke: (_) {
              _togglePlayPause(playbackInfo);
              return null;
            },
          ),
          _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
            onInvoke: (_) {
              _seekBackward10Seconds(playbackInfo);
              return null;
            },
          ),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
            onInvoke: (_) {
              _seekForward10Seconds(playbackInfo);
              return null;
            },
          ),
          _ToggleLoopIntent: CallbackAction<_ToggleLoopIntent>(
            onInvoke: (_) {
              _audioControls.toggleTrackLoop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
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
        final isPlaying = next.value?.isPlaying ?? false;
        _setKeepScreenAwake(isPlaying);
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
        actions: [
          // Favorite toggle button
          Consumer(
            builder: (context, ref, _) {
              final isFavoriteAsync = ref.watch(isFavoriteProvider(widget.track.id));
              return isFavoriteAsync.when(
                data: (isFavorite) => IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: () async {
                    await ref.read(favoriteTrackActionsProvider).toggleFavorite(
                          widget.track.id,
                          widget.track.songId,
                        );

                    // Show snackbar feedback
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite
                                ? 'Removed from favorites'
                                : 'Added to favorites',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                loading: () => const SizedBox(width: 48), // Placeholder for loading
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: playbackInfoAsync.when(
        data: (playbackInfo) {
          return _buildKeyboardShortcuts(
            playbackInfo,
            SafeArea(
              top: false,
              child: _buildPlaybackControls(playbackInfo),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(PlaybackInfo playbackInfo) {
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
                      _seekBackward10Seconds(playbackInfo);
                    },
                  ),
                      IconButton(
                    icon: Icon(
                      playbackInfo.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    ),
                    iconSize: 48,
                    onPressed: () {
                      _togglePlayPause(playbackInfo);
                    },
                  ),
                      IconButton(
                    icon: const Icon(Icons.forward_10),
                    iconSize: 28,
                    onPressed: () {
                      _seekForward10Seconds(playbackInfo);
                    },
                  ),
                      const SizedBox(width: 4),
                      IconButton(
                    icon: Icon(
                      playbackInfo.isTrackLooping ? Icons.repeat_one : Icons.loop,
                    ),
                    tooltip: playbackInfo.isTrackLooping ? 'Disable loop' : 'Enable loop',
                    onPressed: () {
                      ref.read(audioPlayerControlsProvider).toggleTrackLoop();
                    },
                  ),
                      const SizedBox(width: 4),
                      _buildSpeedButton(playbackInfo),
                      const SizedBox(width: 4),
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

  Widget _buildSlider(PlaybackInfo playbackInfo) {
    final double sliderValue = _isDraggingSlider
        ? _dragValue
        : playbackInfo.progress.clamp(0.0, 1.0);

    return Slider(
      key: const ValueKey('progressSlider'),
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

  Widget _buildProgressBar(Track track, PlaybackInfo playbackInfo) {
    final selectedMarkerSetId = ref.watch(selectedMarkerSetProvider);

    if (selectedMarkerSetId == null) {
      return _buildSlider(playbackInfo);
    }

    final markerSetAsync = ref.watch(markerSetByIdProvider(selectedMarkerSetId));
    final markersAsync = ref.watch(markersByMarkerSetProvider(selectedMarkerSetId));

    return markerSetAsync.when(
      data: (markerSet) {
        if (markerSet == null || !markerSet.isTimeSynced) {
          return _buildSlider(playbackInfo);
        }

        return markersAsync.when(
          data: (markers) {
            final loopRange = playbackInfo.loopRange;
            final progressMarkers =
                markers.where((marker) => marker.positionMs != null).toList();
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
          loading: () => _buildSlider(playbackInfo),
          error: (_, __) => _buildSlider(playbackInfo),
        );
      },
      loading: () => _buildSlider(playbackInfo),
      error: (_, __) => _buildSlider(playbackInfo),
    );
  }

  Widget _buildMarkerSection(Track track, PlaybackInfo playbackInfo) {
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
            return MarkerList(
              markers: markers,
              currentPosition: playbackInfo.position,
              trackDuration: playbackInfo.duration,
              showPositions: markerSet.isTimeSynced,
              isPlaying: playbackInfo.isPlaying,
              playbackSpeed: playbackInfo.speed,
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

  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Widget _buildSpeedButton(PlaybackInfo playbackInfo) {
    final speed = playbackInfo.speed;
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}.0x'
        : '${speed}x';

    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      onSelected: (value) {
        ref.read(audioPlayerControlsProvider).setSpeed(value);
      },
      itemBuilder: (context) => _speedOptions.map((s) {
        final itemLabel = s == s.roundToDouble()
            ? '${s.toInt()}.0x'
            : '${s}x';
        return PopupMenuItem<double>(
          value: s,
          child: Text(
            itemLabel,
            style: TextStyle(
              fontWeight: s == speed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: speed != 1.0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
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

class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _ToggleLoopIntent extends Intent {
  const _ToggleLoopIntent();
}
