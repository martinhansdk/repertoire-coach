import 'package:flutter/material.dart';
import '../../domain/entities/marker.dart';

/// List widget displaying markers with tap-to-jump functionality
///
/// Shows markers in chronological order with their labels and positions.
/// Tapping a marker jumps to that position in the track.
class MarkerList extends StatelessWidget {
  final List<Marker> markers;
  final Duration currentPosition;
  final ValueChanged<Duration> onMarkerTap;
  final ValueChanged<Marker>? onMarkerLongPress;

  const MarkerList({
    super.key,
    required this.markers,
    required this.currentPosition,
    required this.onMarkerTap,
    this.onMarkerLongPress,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (markers.isEmpty) {
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
    }

    // Sort markers by position
    final sortedMarkers = List<Marker>.from(markers)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedMarkers.length,
      itemBuilder: (context, index) {
        final marker = sortedMarkers[index];
        final markerPosition = Duration(milliseconds: marker.positionMs);
        final isActive = currentPosition >= markerPosition &&
            (index == sortedMarkers.length - 1 ||
                currentPosition < Duration(milliseconds: sortedMarkers[index + 1].positionMs));

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: isActive
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            marker.label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            _formatDuration(markerPosition),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.play_arrow,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () => onMarkerTap(markerPosition),
          onLongPress: onMarkerLongPress != null
              ? () => onMarkerLongPress!(marker)
              : null,
        );
      },
    );
  }
}
