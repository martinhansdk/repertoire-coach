import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/choir_provider.dart';

/// Dialog for creating a new choir
///
/// Prompts the user to enter a choir name and handles the creation.
/// The current user automatically becomes the owner and first member.
class CreateChoirDialog extends ConsumerStatefulWidget {
  const CreateChoirDialog({super.key});

  @override
  ConsumerState<CreateChoirDialog> createState() => _CreateChoirDialogState();
}

class _CreateChoirDialogState extends ConsumerState<CreateChoirDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createChoir() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final userId = ref.read(currentUserIdProvider);
      final repository = ref.read(choirRepositoryProvider);
      final choirId = await repository.createChoir(
        _nameController.text.trim(),
        userId,
      );

      if (mounted) {
        // Invalidate the choirs list to refresh it
        ref.invalidate(choirsProvider);

        // Return the choir ID to the caller
        Navigator.of(context).pop(choirId);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choir created successfully'),
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
            content: Text('Error creating choir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Choir'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Choir Name',
            hintText: 'Enter the name of your choir',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          enabled: !_isCreating,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a choir name';
            }
            if (value.trim().length < 2) {
              return 'Choir name must be at least 2 characters';
            }
            return null;
          },
          onFieldSubmitted: (_) => _createChoir(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createChoir,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
