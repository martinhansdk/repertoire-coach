import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/track_provider.dart';

/// Dialog for editing an existing track
///
/// Allows the user to update the track name only.
/// Audio files cannot be changed - delete and recreate the track instead.
class EditTrackDialog extends ConsumerStatefulWidget {
  final Track track;

  const EditTrackDialog({
    super.key,
    required this.track,
  });

  @override
  ConsumerState<EditTrackDialog> createState() => _EditTrackDialogState();
}

class _EditTrackDialogState extends ConsumerState<EditTrackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.track.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateTrack() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if anything changed
    final newName = _nameController.text.trim();

    if (newName == widget.track.name) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final repository = ref.read(trackRepositoryProvider);

      // Preserve ALL existing fields except name and updatedAt
      final updatedTrack = Track(
        id: widget.track.id,
        songId: widget.track.songId,
        name: newName,
        audioUrl: widget.track.audioUrl,
        storagePath: widget.track.storagePath,
        durationMs: widget.track.durationMs,
        filePath: widget.track.filePath,
        createdAt: widget.track.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      final success = await repository.updateTrack(updatedTrack);

      if (mounted) {
        if (success) {
          // Invalidate the tracks list to refresh it
          ref.invalidate(tracksBySongProvider);
          ref.invalidate(trackByIdProvider);

          Navigator.of(context).pop(true);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Track updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isUpdating = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Track not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating track: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Track'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Track name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Track Name',
                  hintText: 'Enter the track name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.audiotrack),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                enabled: !_isUpdating,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a track name';
                  }
                  if (value.trim().length < 2) {
                    return 'Track name must be at least 2 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUpdating ? null : _updateTrack,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
