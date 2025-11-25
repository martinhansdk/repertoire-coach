import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/concert.dart';
import '../providers/concert_provider.dart';

/// Dialog for editing an existing concert
///
/// Allows the user to update the concert name and date.
class EditConcertDialog extends ConsumerStatefulWidget {
  final Concert concert;

  const EditConcertDialog({
    super.key,
    required this.concert,
  });

  @override
  ConsumerState<EditConcertDialog> createState() => _EditConcertDialogState();
}

class _EditConcertDialogState extends ConsumerState<EditConcertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late DateTime _selectedDate;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.concert.name);
    _selectedDate = widget.concert.concertDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Concert Date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateConcert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final repository = ref.read(concertRepositoryProvider);

      final updatedConcert = Concert(
        id: widget.concert.id,
        choirId: widget.concert.choirId,
        choirName: widget.concert.choirName,
        name: _nameController.text.trim(),
        concertDate: _selectedDate,
        createdAt: widget.concert.createdAt,
      );

      final success = await repository.updateConcert(updatedConcert);

      if (mounted) {
        if (success) {
          // Invalidate the concerts list to refresh it
          ref.invalidate(concertsProvider);
          ref.invalidate(concertsByChoirProvider);

          // Close dialog
          Navigator.of(context).pop(true);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Concert updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isUpdating = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Concert not found'),
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
            content: Text('Error updating concert: $e'),
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
      title: const Text('Edit Concert'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Concert Name',
                hintText: 'Enter the name of the concert',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              enabled: !_isUpdating,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a concert name';
                }
                if (value.trim().length < 2) {
                  return 'Concert name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isUpdating ? null : _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Date: ${_formatDate(_selectedDate)}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDate.isAfter(DateTime.now())
                  ? 'Upcoming concert'
                  : 'Past concert',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUpdating ? null : _updateConcert,
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
