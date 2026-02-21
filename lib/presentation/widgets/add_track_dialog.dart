import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';

import '../../domain/entities/track.dart';
import '../providers/track_provider.dart';

/// Dialog for creating a new track
///
/// Prompts the user to enter track name and audio file (mandatory).
/// The track is automatically associated with the provided song and choir.
class AddTrackDialog extends ConsumerStatefulWidget {
  final String songId;
  final String songTitle;
  final String choirId;

  const AddTrackDialog({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.choirId,
  });

  @override
  ConsumerState<AddTrackDialog> createState() => _AddTrackDialogState();
}

class _AddTrackDialogState extends ConsumerState<AddTrackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _filePathController = TextEditingController();

  // Store selected file info
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb, // Load bytes on web
      );

      if (result != null) {
        final file = result.files.single;

        setState(() {
          if (kIsWeb) {
            // On web, use bytes
            _selectedFileBytes = file.bytes;
            _selectedFileName = file.name;
            _selectedFilePath = null;
            _filePathController.text = file.name;
          } else {
            // On mobile/desktop, use path
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _selectedFileBytes = null;
            _filePathController.text = file.path ?? file.name;
          }
        });
      }
    } catch (e) {
      // Log error to console for easier debugging
      debugPrint('ERROR - File picker failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _createTrack() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that audio file is selected
    if (_selectedFilePath == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an audio file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final trackId = const Uuid().v4();
      final audioStorageService = ref.read(audioStorageServiceProvider);

      // Debug: Log upload parameters
      debugPrint('DEBUG - Uploading audio: choirId=${widget.choirId}, trackId=$trackId');

      // Upload audio file to Supabase Storage
      final uploadResult = kIsWeb
          ? await audioStorageService.uploadAudioFromBytes(
              bytes: _selectedFileBytes!,
              fileName: _selectedFileName!,
              choirId: widget.choirId,
              trackId: trackId,
            )
          : await audioStorageService.uploadAudioFromFile(
              filePath: _selectedFilePath!,
              choirId: widget.choirId,
              trackId: trackId,
            );

      // Create track with uploaded audio URL
      final repository = ref.read(trackRepositoryProvider);
      final now = DateTime.now().toUtc();

      final track = Track(
        id: trackId,
        songId: widget.songId,
        name: _nameController.text.trim(),
        storagePath: uploadResult.storagePath,
        durationMs: uploadResult.durationMs,
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
      // Log error to console for easier debugging
      debugPrint('ERROR - Track creation failed: $e');
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
                  hintText: 'e.g., Soprano Part, Full Choir, etc.',
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

              // File path field with picker button
              TextFormField(
                controller: _filePathController,
                decoration: InputDecoration(
                  labelText: 'Audio File *',
                  hintText: 'Select an audio file',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.audiotrack),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _isCreating ? null : _pickAudioFile,
                    tooltip: 'Browse for audio file',
                  ),
                  helperText: 'Required - Works on all platforms including web',
                ),
                enabled: !_isCreating,
                readOnly: true,
                onTap: _isCreating ? null : _pickAudioFile,
                validator: (value) {
                  if (_selectedFilePath == null && _selectedFileBytes == null) {
                    return 'Please select an audio file';
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
