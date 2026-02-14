import 'package:flutter/material.dart';
import '../../domain/entities/marker.dart';

/// Animated marker item that smoothly shows playback progress
class _AnimatedMarkerItem extends StatefulWidget {
  final int index;
  final Marker marker;
  final bool isActive;
  final Duration segmentDuration;
  final Duration currentPosition;
  final Duration markerPosition;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showPositions;
  final bool isPlaying;

  const _AnimatedMarkerItem({
    required this.index,
    required this.marker,
    required this.isActive,
    required this.segmentDuration,
    required this.currentPosition,
    required this.markerPosition,
    this.onTap,
    this.onLongPress,
    required this.showPositions,
    required this.isPlaying,
  });

  @override
  State<_AnimatedMarkerItem> createState() => _AnimatedMarkerItemState();
}

class _AnimatedMarkerItemState extends State<_AnimatedMarkerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.segmentDuration,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _updateAnimation();
  }

  @override
  void didUpdateWidget(_AnimatedMarkerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset if we switched to a different marker being active
    if (widget.isActive != oldWidget.isActive) {
      _updateAnimation();
    }
    // Update if playing state changed
    else if (widget.isPlaying != oldWidget.isPlaying) {
      _updateAnimation();
    }
    // Update if segment duration changed
    else if (widget.segmentDuration != oldWidget.segmentDuration) {
      _controller.duration = widget.segmentDuration;
      _updateAnimation();
    }
    // Update if position jumped (seeking)
    else if (widget.isActive && oldWidget.isActive) {
      final elapsed = (widget.currentPosition - widget.markerPosition).inMilliseconds;
      final totalDuration = widget.segmentDuration.inMilliseconds;
      if (totalDuration > 0) {
        final targetProgress = (elapsed / totalDuration).clamp(0.0, 1.0);
        // If position jumped significantly, reset animation
        if ((targetProgress - _controller.value).abs() > 0.1) {
          _controller.value = targetProgress;
          if (targetProgress < 1.0 && widget.isPlaying) {
            _controller.forward(from: targetProgress);
          }
        }
      }
    }
  }

  void _updateAnimation() {
    if (widget.isActive && widget.showPositions) {
      // Calculate how far into the segment we are
      final elapsed = (widget.currentPosition - widget.markerPosition).inMilliseconds;
      final totalDuration = widget.segmentDuration.inMilliseconds;

      if (totalDuration > 0 && elapsed >= 0) {
        final progress = (elapsed / totalDuration).clamp(0.0, 1.0);
        _controller.duration = widget.segmentDuration;
        _controller.value = progress;

        // Start animation from current position only if playing
        if (progress < 1.0 && widget.isPlaying) {
          _controller.forward(from: progress);
        } else if (!widget.isPlaying) {
          // Pause at current position
          _controller.stop();
        }
      } else {
        _controller.reset();
      }
    } else {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.marker.label.isEmpty) {
      return Container(
        key: ValueKey('markerSpacer_${widget.index}'),
        height: 30.0,
        color: theme.scaffoldBackgroundColor,
      );
    }

    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        children: [
          Container(
            height: 30.0,
            color: theme.scaffoldBackgroundColor,
          ),
          if (widget.showPositions && widget.isActive)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    key: ValueKey('markerProgress_${widget.index}'),
                    alignment: Alignment.centerLeft,
                    widthFactor: _animation.value,
                    child: child,
                  );
                },
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.28),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.marker.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: widget.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List widget displaying markers with tap-to-jump functionality
///
/// Shows markers in chronological order with their labels and positions.
/// Tapping a marker jumps to that position in the track.
class MarkerList extends StatefulWidget {
  final List<Marker> markers;
  final Duration currentPosition;
  final ValueChanged<Duration>? onMarkerTap;
  final ValueChanged<Marker>? onMarkerLongPress;
  final bool showPositions;
  final Duration? trackDuration;
  final bool isPlaying;

  const MarkerList({
    super.key,
    required this.markers,
    required this.currentPosition,
    required this.onMarkerTap,
    this.onMarkerLongPress,
    this.showPositions = true,
    this.trackDuration,
    this.isPlaying = false,
  });

  @override
  State<MarkerList> createState() => _MarkerListState();
}

class _MarkerListState extends State<MarkerList> {
  static const double _itemExtent = 30.0;
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _findActiveIndex(List<Marker> markers) {
    if (!widget.showPositions || markers.isEmpty) return -1;
    for (int i = 0; i < markers.length; i++) {
      final markerPosition = Duration(milliseconds: markers[i].positionMs);
      final nextPosition = i == markers.length - 1
          ? (widget.trackDuration ?? markerPosition)
          : Duration(milliseconds: markers[i + 1].positionMs);
      if (widget.currentPosition >= markerPosition &&
          (i == markers.length - 1 || widget.currentPosition < nextPosition)) {
        return i;
      }
    }
    return -1;
  }

  void _centerActiveMarker(int index) {
    if (index < 0) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerActiveMarker(index);
      });
      return;
    }
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * _itemExtent) - (viewportHeight / 2) + (_itemExtent / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.markers.isEmpty) {
      return ListView.builder(
        key: const ValueKey('markerListScroll'),
        controller: _scrollController,
        itemCount: 1,
        itemBuilder: (context, index) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No markers in this set',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      );
    }

    // Sort markers by display order (empty labels preserved)
    final sortedMarkers = List<Marker>.from(widget.markers)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (sortedMarkers.isEmpty) {
      return ListView.builder(
        key: const ValueKey('markerListScroll'),
        controller: _scrollController,
        itemCount: 1,
        itemBuilder: (context, index) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No markers in this set',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      );
    }

    final activeIndex = _findActiveIndex(sortedMarkers);
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerActiveMarker(activeIndex);
      });
    }

    return ListView.builder(
      key: const ValueKey('markerListScroll'),
      controller: _scrollController,
      itemExtent: _itemExtent,
      itemCount: sortedMarkers.length,
      itemBuilder: (context, index) {
        final marker = sortedMarkers[index];
        final markerPosition = Duration(milliseconds: marker.positionMs);
        final isActive = index == activeIndex;
        final nextPosition = index == sortedMarkers.length - 1
            ? (widget.trackDuration ?? markerPosition)
            : Duration(milliseconds: sortedMarkers[index + 1].positionMs);
        final segmentDuration = nextPosition > markerPosition
            ? nextPosition - markerPosition
            : const Duration(milliseconds: 1);

        return _AnimatedMarkerItem(
          index: index,
          marker: marker,
          isActive: isActive,
          segmentDuration: segmentDuration,
          currentPosition: widget.currentPosition,
          markerPosition: markerPosition,
          onTap: widget.onMarkerTap != null ? () => widget.onMarkerTap!(markerPosition) : null,
          onLongPress: widget.onMarkerLongPress != null ? () => widget.onMarkerLongPress!(marker) : null,
          showPositions: widget.showPositions,
          isPlaying: widget.isPlaying,
        );
      },
    );
  }
}
