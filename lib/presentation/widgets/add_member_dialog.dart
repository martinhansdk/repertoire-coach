import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/choir_provider.dart';

/// Dialog for adding a member to a choir by email.
///
/// Looks up the user ID from the entered email via the users table,
/// then adds that user to the choir.
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
  final _emailController = TextEditingController();
  bool _isAdding = false;
  /// Inline error shown below the text field (distinct from SnackBar errors).
  String? _lookupError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isAdding = true;
      _lookupError = null;
    });

    final email = _emailController.text.trim();

    try {
      // 1. Resolve email → user ID
      final lookup = ref.read(userLookupProvider);
      final userId = await lookup.findUserIdByEmail(email);

      if (userId == null) {
        if (mounted) {
          setState(() {
            _isAdding = false;
            _lookupError = 'No account found for this email';
          });
        }
        return;
      }

      // 2. Add member to choir
      final repository = ref.read(choirRepositoryProvider);
      await repository.addMember(widget.choirId, userId);

      if (mounted) {
        ref.invalidate(choirMembersProvider(widget.choirId));
        ref.invalidate(choirMemberProfilesProvider(widget.choirId));
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
          _lookupError = _formatError(e);
        });
      }
    }
  }

  String _formatError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('UNIQUE constraint failed') ||
        errorStr.contains('duplicate key')) {
      return 'This person is already a member of the choir';
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
              'Enter the email of the person you want to add.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'member@example.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
                errorText: _lookupError,
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              enabled: !_isAdding,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
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
