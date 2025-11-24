import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/choir_provider.dart';

/// Dialog for adding a member to a choir
///
/// PHASE 1: Simple user ID input for testing
/// PHASE 2: Will add email lookup with Supabase Auth
class AddMemberDialog extends ConsumerStatefulWidget {
  final String choirId;

  const AddMemberDialog({
    super.key,
    required this.choirId,
  });

  @override
  ConsumerState<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final repository = ref.read(choirRepositoryProvider);
      await repository.addMember(
        widget.choirId,
        _userIdController.text.trim(),
      );

      if (mounted) {
        // Invalidate providers to refresh data
        ref.invalidate(choirMembersProvider(widget.choirId));
        ref.invalidate(choirMemberCountProvider(widget.choirId));

        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: ${_formatError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('UNIQUE constraint failed')) {
      return 'This user is already a member of the choir';
    }
    return errorStr;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phase 1: Enter user ID directly',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phase 2 will support email lookup',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'e.g., user2, user3',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              enabled: !_isAdding,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a user ID';
                }
                return null;
              },
              onFieldSubmitted: (_) => _addMember(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isAdding ? null : _addMember,
          child: _isAdding
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
