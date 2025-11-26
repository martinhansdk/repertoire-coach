import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../providers/track_provider.dart';

/// Dialog for editing an existing track
///
/// Allows the user to update the track name, voice part, and file path.
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
  late final TextEditingController _filePathController;
  late final TextEditingController _customVoicePartController;

  // Voice part options
  static const voicePartOptions = [
    'Soprano',
    'Alto',
    'Tenor',
    'Bass',
    'Custom',
  ];

  late String _selectedVoicePart;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.track.name);
    _filePathController = TextEditingController(text: widget.track.filePath ?? '');

    // Determine if voice part is a standard one or custom
    if (voicePartOptions.contains(widget.track.voicePart)) {
      _selectedVoicePart = widget.track.voicePart;
      _customVoicePartController = TextEditingController();
    } else {
      _selectedVoicePart = 'Custom';
      _customVoicePartController = TextEditingController(text: widget.track.voicePart);
    }
  }

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

  Future<void> _updateTrack() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if anything changed
    final newName = _nameController.text.trim();
    final newVoicePart = _getVoicePart();
    final newFilePath = _filePathController.text.trim();

    if (newName == widget.track.name &&
        newVoicePart == widget.track.voicePart &&
        (newFilePath.isEmpty ? null : newFilePath) == widget.track.filePath) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final repository = ref.read(trackRepositoryProvider);

      final updatedTrack = Track(
        id: widget.track.id,
        songId: widget.track.songId,
        name: newName,
        voicePart: newVoicePart,
        filePath: newFilePath.isEmpty ? null : newFilePath,
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
    final isCustomVoicePart = _selectedVoicePart == 'Custom';

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
                onChanged: _isUpdating ? null : (value) {
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
                  enabled: !_isUpdating,
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
                enabled: !_isUpdating,
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
