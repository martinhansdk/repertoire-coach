import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/marker_set.dart';
import '../providers/selected_marker_set_provider.dart';

/// Chip widget for selecting a marker set via a bottom sheet.
///
/// Shows the selected set name as a compact chip. Tapping opens a bottom
/// sheet with the full list of sets and an optional manage action.
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
    final selectedId = ref.watch(selectedMarkerSetProvider);

    if (markerSets.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMarkerSetProvider.notifier).state = null;
      });
      return ActionChip(
        avatar: const Icon(Icons.bookmarks_outlined, size: 16),
        label: const Text('Markers'),
        onPressed: onManageMarkers,
      );
    }

    // Ensure selected ID is valid, otherwise select first
    final validSelectedId = markerSets.any((set) => set.id == selectedId)
        ? selectedId
        : markerSets.first.id;

    if (validSelectedId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMarkerSetProvider.notifier).state = validSelectedId;
      });
    }

    final selectedSet = markerSets.firstWhere((set) => set.id == validSelectedId);

    return ActionChip(
      avatar: const Icon(Icons.bookmarks, size: 16),
      label: Text(
        selectedSet.name,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => _showMarkerSetSheet(context, ref, validSelectedId),
    );
  }

  void _showMarkerSetSheet(BuildContext context, WidgetRef ref, String? selectedId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _MarkerSetSheet(
        markerSets: markerSets,
        selectedId: selectedId,
        onSelected: (id) {
          ref.read(selectedMarkerSetProvider.notifier).state = id;
          Navigator.pop(context);
        },
        onManageMarkers: onManageMarkers != null
            ? () {
                Navigator.pop(context);
                onManageMarkers!();
              }
            : null,
      ),
    );
  }
}

class _MarkerSetSheet extends StatelessWidget {
  final List<MarkerSet> markerSets;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onManageMarkers;

  const _MarkerSetSheet({
    required this.markerSets,
    required this.selectedId,
    required this.onSelected,
    this.onManageMarkers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Text('Marker sets', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (onManageMarkers != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Manage markers',
                      onPressed: onManageMarkers,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Marker set list
            ...markerSets.map((set) {
              final isSelected = set.id == selectedId;
              return ListTile(
                leading: Icon(
                  set.isShared ? Icons.people : Icons.lock,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(set.name),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                selected: isSelected,
                onTap: () => onSelected(set.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}
