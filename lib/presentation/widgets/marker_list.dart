import 'package:flutter/material.dart';
import '../../domain/entities/marker.dart';

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

  const MarkerList({
    super.key,
    required this.markers,
    required this.currentPosition,
    required this.onMarkerTap,
    this.onMarkerLongPress,
    this.showPositions = true,
    this.trackDuration,
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
        final elapsed = (widget.currentPosition - markerPosition).inMilliseconds;
        final progress = widget.showPositions && isActive
            ? (elapsed / segmentDuration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        if (marker.label.isEmpty) {
          return Container(
            key: ValueKey('markerSpacer_$index'),
            height: _itemExtent,
            color: theme.scaffoldBackgroundColor,
          );
        }

        return InkWell(
          onTap: widget.onMarkerTap != null ? () => widget.onMarkerTap!(markerPosition) : null,
          onLongPress: widget.onMarkerLongPress != null ? () => widget.onMarkerLongPress!(marker) : null,
          child: Stack(
            children: [
              Container(
                height: _itemExtent,
                color: theme.scaffoldBackgroundColor,
              ),
              if (widget.showPositions && isActive)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        key: ValueKey('markerProgress_$index'),
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
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
                    marker.label,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
