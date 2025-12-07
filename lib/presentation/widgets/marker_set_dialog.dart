import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/marker_set.dart';
import '../providers/marker_provider.dart';

/// Hardcoded user ID for local-first mode (before authentication)
const String _currentUserId = 'local-user-1';

/// Dialog for creating or editing a marker set
///
/// When [markerSet] is null, creates a new marker set.
/// When [markerSet] is provided, edits the existing marker set.
class MarkerSetDialog extends ConsumerStatefulWidget {
  final String trackId;
  final MarkerSet? markerSet; // null for create, non-null for edit

  const MarkerSetDialog({
    super.key,
    required this.trackId,
    this.markerSet,
  });

  @override
  ConsumerState<MarkerSetDialog> createState() => _MarkerSetDialogState();
}

class _MarkerSetDialogState extends ConsumerState<MarkerSetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isShared;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.markerSet?.name ?? '',
    );
    _isShared = widget.markerSet?.isShared ?? false; // Default to private (not shared)
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveMarkerSet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For editing, check if anything changed
    if (widget.markerSet != null) {
      final newName = _nameController.text.trim();
      if (newName == widget.markerSet!.name && _isShared == widget.markerSet!.isShared) {
        Navigator.of(context).pop(false);
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(markerRepositoryProvider);
      final now = DateTime.now().toUtc();

      if (widget.markerSet == null) {
        // Create new marker set
        final markerSet = MarkerSet(
          id: const Uuid().v4(),
          trackId: widget.trackId,
          name: _nameController.text.trim(),
          isShared: _isShared,
          createdByUserId: _currentUserId,
          createdAt: now,
          updatedAt: now,
        );

        await repository.createMarkerSet(markerSet);

        if (mounted) {
          // Invalidate the marker sets list to refresh it
          ref.invalidate(markerSetsByTrackProvider);

          // Show success message before closing
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marker set created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pop(markerSet.id);
        }
      } else {
        // Update existing marker set
        final updatedMarkerSet = MarkerSet(
          id: widget.markerSet!.id,
          trackId: widget.markerSet!.trackId,
          name: _nameController.text.trim(),
          isShared: _isShared,
          createdByUserId: widget.markerSet!.createdByUserId,
          createdAt: widget.markerSet!.createdAt,
          updatedAt: now,
        );

        final success = await repository.updateMarkerSet(updatedMarkerSet);

        if (mounted) {
          if (success) {
            // Invalidate the marker sets list to refresh it
            ref.invalidate(markerSetsByTrackProvider);
            ref.invalidate(markerSetByIdProvider);

            // Show success message before closing
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Marker set updated successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            Navigator.of(context).pop(true);
          } else {
            throw Exception('Failed to update marker set');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving marker set: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.markerSet != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Marker Set' : 'New Marker Set'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Set Name',
                hintText: 'e.g., Structure, Rehearsal Marks',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bookmark),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: !isEditing,
              enabled: !_isSaving,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Privacy toggle
            SwitchListTile(
              title: const Text('Shared'),
              subtitle: Text(
                _isShared
                    ? 'Visible to all choir members'
                    : 'Private - only you can see this',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _isShared,
              onChanged: _isSaving ? null : (value) {
                setState(() {
                  _isShared = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveMarkerSet,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
