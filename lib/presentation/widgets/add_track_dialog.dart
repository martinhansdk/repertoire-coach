import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/track.dart';
import '../providers/track_provider.dart';

/// Dialog for creating a new track
///
/// Prompts the user to enter track name, voice part, and optional file path.
/// The track is automatically associated with the provided song.
class AddTrackDialog extends ConsumerStatefulWidget {
  final String songId;
  final String songTitle;

  const AddTrackDialog({
    super.key,
    required this.songId,
    required this.songTitle,
  });

  @override
  ConsumerState<AddTrackDialog> createState() => _AddTrackDialogState();
}

class _AddTrackDialogState extends ConsumerState<AddTrackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _filePathController = TextEditingController();

  // Voice part options
  static const voicePartOptions = [
    'Soprano',
    'Alto',
    'Tenor',
    'Bass',
    'Custom',
  ];

  String _selectedVoicePart = 'Soprano';
  final _customVoicePartController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _filePathController.dispose();
    _customVoicePartController.dispose();
    super.dispose();
  }

  String _getVoicePart() {
    if (_selectedVoicePart == 'Custom') {
      return _customVoicePartController.text.trim();
    }
    return _selectedVoicePart;
  }

  Future<void> _createTrack() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final repository = ref.read(trackRepositoryProvider);
      final now = DateTime.now().toUtc();

      final filePath = _filePathController.text.trim();

      final track = Track(
        id: const Uuid().v4(),
        songId: widget.songId,
        name: _nameController.text.trim(),
        voicePart: _getVoicePart(),
        filePath: filePath.isEmpty ? null : filePath,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTrack(track);

      if (mounted) {
        // Invalidate the tracks list to refresh it
        ref.invalidate(tracksBySongProvider);

        // Return the track ID to the caller
        Navigator.of(context).pop(track.id);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Track created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating track: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustomVoicePart = _selectedVoicePart == 'Custom';

    return AlertDialog(
      title: const Text('Add New Track'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Song: ${widget.songTitle}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

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
                enabled: !_isCreating,
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
              const SizedBox(height: 16),

              // Voice part dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedVoicePart,
                decoration: const InputDecoration(
                  labelText: 'Voice Part',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: voicePartOptions.map((part) {
                  return DropdownMenuItem(
                    value: part,
                    child: Text(part),
                  );
                }).toList(),
                onChanged: _isCreating ? null : (value) {
                  setState(() {
                    _selectedVoicePart = value!;
                  });
                },
              ),

              // Custom voice part field (shown when Custom is selected)
              if (isCustomVoicePart) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customVoicePartController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Voice Part',
                    hintText: 'Enter custom voice part',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  textCapitalization: TextCapitalization.words,
                  enabled: !_isCreating,
                  validator: (value) {
                    if (isCustomVoicePart && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a custom voice part';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),

              // File path field (optional)
              TextFormField(
                controller: _filePathController,
                decoration: const InputDecoration(
                  labelText: 'File Path (Optional)',
                  hintText: 'Enter file path to audio file',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.file_present),
                ),
                enabled: !_isCreating,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createTrack,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
