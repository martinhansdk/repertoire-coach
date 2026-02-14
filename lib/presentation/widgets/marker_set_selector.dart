import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/marker_set.dart';
import '../providers/selected_marker_set_provider.dart';

/// Dropdown widget for selecting a marker set
///
/// Displays a dropdown of available marker sets for the current track.
/// Updates the selected marker set provider when selection changes.
class MarkerSetSelector extends ConsumerWidget {
  final List<MarkerSet> markerSets;
  final VoidCallback? onManageMarkers;
  final bool compact;

  const MarkerSetSelector({
    super.key,
    required this.markerSets,
    this.onManageMarkers,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedMarkerSetProvider);

    if (markerSets.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMarkerSetProvider.notifier).state = null;
      });
      return _EmptyState(onManageMarkers: onManageMarkers);
    }

    // Ensure selected ID is valid, otherwise select first
    final validSelectedId = markerSets.any((set) => set.id == selectedId)
        ? selectedId
        : markerSets.first.id;

    // Update selection if it was invalid
    if (validSelectedId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMarkerSetProvider.notifier).state = validSelectedId;
      });
    }

    // Use LayoutBuilder to check available space and decide on compact mode
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedMarkerSet = markerSets.firstWhere((set) => set.id == validSelectedId);

        // Estimate text width (rough estimate: 8px per character)
        final estimatedTextWidth = selectedMarkerSet.name.length * 8.0;
        // Add overhead for icon (24) + padding (16) + dropdown icon (24) + manage button (48)
        final estimatedTotalWidth = estimatedTextWidth + 112;

        // If estimated width exceeds available space and we have a manage button, use compact mode
        final shouldUseCompactMode = estimatedTotalWidth > constraints.maxWidth && onManageMarkers != null;

        if (shouldUseCompactMode) {
          return IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: 'Manage Markers',
            onPressed: onManageMarkers,
          );
        }

        // Show full dropdown
        return Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: validSelectedId,
                isExpanded: true,
                items: markerSets.map((markerSet) {
                  return DropdownMenuItem<String>(
                    value: markerSet.id,
                    child: compact
                        ? Text(
                            markerSet.name,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Row(
                            children: [
                              Icon(
                                markerSet.isShared ? Icons.people : Icons.lock,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  markerSet.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    ref.read(selectedMarkerSetProvider.notifier).state = newValue;
                  }
                },
              ),
            ),
            if (onManageMarkers != null && !compact) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Manage Markers',
                onPressed: onManageMarkers,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Empty state when no marker sets are available
class _EmptyState extends StatelessWidget {
  final VoidCallback? onManageMarkers;

  const _EmptyState({this.onManageMarkers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use LayoutBuilder to check if full empty state fits
    return LayoutBuilder(
      builder: (context, constraints) {
        // Estimate width needed: icon (24) + padding (24) + text (~110) + button (~90) + padding (24)
        const estimatedWidth = 272.0;

        // If it doesn't fit and we have a manage button, show compact version
        if (constraints.maxWidth < estimatedWidth && onManageMarkers != null) {
          return IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Create Marker Set',
            onPressed: onManageMarkers,
          );
        }

        // Show full empty state
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bookmarks_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No marker sets',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (onManageMarkers != null)
                TextButton.icon(
                  onPressed: onManageMarkers,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
            ],
          ),
        );
      },
    );
  }
}
