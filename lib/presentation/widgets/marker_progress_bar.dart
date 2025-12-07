import 'package:flutter/material.dart';
import '../../domain/entities/marker.dart';

/// Custom progress bar that displays markers along the timeline
///
/// Shows the current playback position and allows seeking by tapping.
/// Markers are displayed as vertical lines at their positions.
class MarkerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final List<Marker> markers;
  final ValueChanged<Duration> onSeek;
  final Duration? loopStart;
  final Duration? loopEnd;

  const MarkerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.markers,
    required this.onSeek,
    this.loopStart,
    this.loopEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double progress = duration.inMicroseconds > 0
        ? position.inMicroseconds / duration.inMicroseconds
        : 0.0;

    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = details.localPosition.dx;
        final width = box.size.width;
        final seekFraction = (localPosition / width).clamp(0.0, 1.0);
        final seekPosition = Duration(
          microseconds: (duration.inMicroseconds * seekFraction).round(),
        );
        onSeek(seekPosition);
      },
      child: SizedBox(
        height: 48,
        child: CustomPaint(
          size: const Size(double.infinity, 48),
          painter: _MarkerProgressPainter(
            progress: progress,
            markers: markers,
            duration: duration,
            loopStart: loopStart,
            loopEnd: loopEnd,
            progressColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            markerColor: theme.colorScheme.secondary,
            loopColor: theme.colorScheme.tertiary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the marker progress bar
class _MarkerProgressPainter extends CustomPainter {
  final double progress;
  final List<Marker> markers;
  final Duration duration;
  final Duration? loopStart;
  final Duration? loopEnd;
  final Color progressColor;
  final Color backgroundColor;
  final Color markerColor;
  final Color loopColor;

  _MarkerProgressPainter({
    required this.progress,
    required this.markers,
    required this.duration,
    this.loopStart,
    this.loopEnd,
    required this.progressColor,
    required this.backgroundColor,
    required this.markerColor,
    required this.loopColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 4.0;
    final trackY = size.height / 2 - trackHeight / 2;

    // Draw background track
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, size.width, trackHeight),
        const Radius.circular(2),
      ),
      backgroundPaint,
    );

    // Draw loop range if active
    if (loopStart != null && loopEnd != null && duration.inMicroseconds > 0) {
      final loopStartFraction = loopStart!.inMicroseconds / duration.inMicroseconds;
      final loopEndFraction = loopEnd!.inMicroseconds / duration.inMicroseconds;
      final loopStartX = size.width * loopStartFraction;
      final loopEndX = size.width * loopEndFraction;

      final loopPaint = Paint()
        ..color = loopColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(loopStartX, trackY, loopEndX - loopStartX, trackHeight),
          const Radius.circular(2),
        ),
        loopPaint,
      );
    }

    // Draw progress
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.fill;

    final progressWidth = size.width * progress;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, progressWidth, trackHeight),
        const Radius.circular(2),
      ),
      progressPaint,
    );

    // Draw markers
    if (duration.inMicroseconds > 0) {
      final markerPaint = Paint()
        ..color = markerColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (final marker in markers) {
        final markerFraction = marker.positionMs / duration.inMilliseconds;
        final markerX = size.width * markerFraction;

        // Draw vertical line for marker
        canvas.drawLine(
          Offset(markerX, trackY - 8),
          Offset(markerX, trackY + trackHeight + 8),
          markerPaint,
        );

        // Draw small circle at top
        final circlePaint = Paint()
          ..color = markerColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(markerX, trackY - 8),
          3,
          circlePaint,
        );
      }
    }

    // Draw playhead (current position indicator)
    if (progress > 0) {
      final playheadPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;

      final playheadX = size.width * progress;

      // Draw circle for playhead
      canvas.drawCircle(
        Offset(playheadX, size.height / 2),
        8,
        playheadPaint,
      );

      // Draw white border
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(
        Offset(playheadX, size.height / 2),
        8,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkerProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        markers != oldDelegate.markers ||
        loopStart != oldDelegate.loopStart ||
        loopEnd != oldDelegate.loopEnd;
  }
}
