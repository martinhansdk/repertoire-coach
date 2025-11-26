import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song.dart';
import '../providers/song_provider.dart';

/// Dialog for editing an existing song
///
/// Allows the user to update the song title.
class EditSongDialog extends ConsumerStatefulWidget {
  final Song song;

  const EditSongDialog({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends ConsumerState<EditSongDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _updateSong() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if anything changed
    final newTitle = _titleController.text.trim();
    if (newTitle == widget.song.title) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final repository = ref.read(songRepositoryProvider);

      final updatedSong = Song(
        id: widget.song.id,
        concertId: widget.song.concertId,
        title: newTitle,
        createdAt: widget.song.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      final success = await repository.updateSong(updatedSong);

      if (mounted) {
        if (success) {
          // Invalidate the songs list to refresh it
          ref.invalidate(songsByConcertProvider);
          ref.invalidate(songByIdProvider);

          Navigator.of(context).pop(true);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isUpdating = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song not found'),
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
            content: Text('Error updating song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Song'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              enabled: !_isUpdating,
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
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUpdating ? null : _updateSong,
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
