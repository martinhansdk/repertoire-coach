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

  const MarkerSetSelector({
    super.key,
    required this.markerSets,
    this.onManageMarkers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.watch(selectedMarkerSetProvider);
    final selectedId = notifier.selectedMarkerSetId;

    if (markerSets.isEmpty) {
      return _EmptyState(onManageMarkers: onManageMarkers);
    }

    // Ensure selected ID is valid, otherwise select first
    final validSelectedId = markerSets.any((set) => set.id == selectedId)
        ? selectedId
        : markerSets.first.id;

    // Update selection if it was invalid
    if (validSelectedId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.select(validSelectedId);
      });
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            value: validSelectedId,
            isExpanded: true,
            items: markerSets.map((markerSet) {
              return DropdownMenuItem<String>(
                value: markerSet.id,
                child: Row(
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
                notifier.select(newValue);
              }
            },
          ),
        ),
        if (onManageMarkers != null) ...[
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.5),
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
