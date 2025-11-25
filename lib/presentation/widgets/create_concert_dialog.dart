import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/concert.dart';
import '../providers/concert_provider.dart';

/// Dialog for creating a new concert
///
/// Prompts the user to enter a concert name and date.
/// The concert is automatically associated with the provided choir.
class CreateConcertDialog extends ConsumerStatefulWidget {
  final String choirId;
  final String choirName;

  const CreateConcertDialog({
    super.key,
    required this.choirId,
    required this.choirName,
  });

  @override
  ConsumerState<CreateConcertDialog> createState() =>
      _CreateConcertDialogState();
}

class _CreateConcertDialogState extends ConsumerState<CreateConcertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  bool _isCreating = false;

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
      initialDate: _selectedDate ?? now,
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

  Future<void> _createConcert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a concert date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final repository = ref.read(concertRepositoryProvider);
      final now = DateTime.now().toUtc();

      final concert = Concert(
        id: const Uuid().v4(),
        choirId: widget.choirId,
        choirName: widget.choirName,
        name: _nameController.text.trim(),
        concertDate: _selectedDate!,
        createdAt: now,
      );

      await repository.createConcert(concert);

      if (mounted) {
        // Invalidate the concerts list to refresh it
        ref.invalidate(concertsProvider);
        ref.invalidate(concertsByChoirProvider);

        // Return the concert ID to the caller
        Navigator.of(context).pop(concert.id);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concert created successfully'),
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
            content: Text('Error creating concert: $e'),
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
      title: const Text('Create New Concert'),
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
              enabled: !_isCreating,
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
              onPressed: _isCreating ? null : _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? 'Select Date'
                    : 'Date: ${_formatDate(_selectedDate!)}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                foregroundColor: _selectedDate == null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.primary,
              ),
            ),
            if (_selectedDate != null) ...[
              const SizedBox(height: 8),
              Text(
                _selectedDate!.isAfter(DateTime.now())
                    ? 'Upcoming concert'
                    : 'Past concert',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createConcert,
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
