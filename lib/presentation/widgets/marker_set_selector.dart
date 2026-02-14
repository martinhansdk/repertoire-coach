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
    final screenWidth = MediaQuery.of(context).size.width;
    // Use compact mode on mobile devices (including high-DPI phones like 1080px)
    final isNarrowScreen = screenWidth < 1200; // Narrow if width < 1200dp (mobile devices)

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

    // On narrow screens, only show the manage button (bookmarks icon)
    if (isNarrowScreen && onManageMarkers != null) {
      return IconButton(
        icon: const Icon(Icons.bookmarks),
        tooltip: 'Manage Markers',
        onPressed: onManageMarkers,
      );
    }

    // On wider screens, show full dropdown + manage button
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
  }
}

/// Empty state when no marker sets are available
class _EmptyState extends StatelessWidget {
  final VoidCallback? onManageMarkers;

  const _EmptyState({this.onManageMarkers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrowScreen = screenWidth < 1200;

    // On narrow screens, just show the manage button without the container
    if (isNarrowScreen && onManageMarkers != null) {
      return IconButton(
        icon: const Icon(Icons.bookmarks_outlined),
        tooltip: 'Create Marker Set',
        onPressed: onManageMarkers,
      );
    }

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
  }
}
