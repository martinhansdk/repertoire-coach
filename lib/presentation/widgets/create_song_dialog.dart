import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/song.dart';
import '../providers/song_provider.dart';

/// Dialog for creating a new song
///
/// Prompts the user to enter a song title.
/// The song is automatically associated with the provided concert.
class CreateSongDialog extends ConsumerStatefulWidget {
  final String concertId;
  final String concertName;

  const CreateSongDialog({
    super.key,
    required this.concertId,
    required this.concertName,
  });

  @override
  ConsumerState<CreateSongDialog> createState() => _CreateSongDialogState();
}

class _CreateSongDialogState extends ConsumerState<CreateSongDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createSong() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final repository = ref.read(songRepositoryProvider);
      final now = DateTime.now().toUtc();

      final song = Song(
        id: const Uuid().v4(),
        concertId: widget.concertId,
        title: _titleController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createSong(song);

      if (mounted) {
        // Invalidate the songs list to refresh it
        ref.invalidate(songsByConcertProvider);

        // Return the song ID to the caller
        Navigator.of(context).pop(song.id);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Song created successfully'),
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
            content: Text('Error creating song: $e'),
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
      title: const Text('Add New Song'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Concert: ${widget.concertName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Song Title',
                hintText: 'Enter the song title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.music_note),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              enabled: !_isCreating,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a song title';
                }
                if (value.trim().length < 2) {
                  return 'Song title must be at least 2 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createSong,
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
