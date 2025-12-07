import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/marker.dart';
import '../providers/audio_player_provider.dart';
import '../providers/marker_provider.dart';

/// Dialog for creating or editing a marker
///
/// When [marker] is null, creates a new marker.
/// When [marker] is provided, edits the existing marker.
class MarkerDialog extends ConsumerStatefulWidget {
  final String markerSetId;
  final Marker? marker; // null for create, non-null for edit
  final int? initialPositionMs; // Used when creating from current playback position

  const MarkerDialog({
    super.key,
    required this.markerSetId,
    this.marker,
    this.initialPositionMs,
  });

  @override
  ConsumerState<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends ConsumerState<MarkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  late final TextEditingController _millisecondsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize label
    _labelController = TextEditingController(
      text: widget.marker?.label ?? '',
    );

    // Initialize time fields from position
    final int positionMs;
    if (widget.marker != null) {
      positionMs = widget.marker!.positionMs;
    } else if (widget.initialPositionMs != null) {
      positionMs = widget.initialPositionMs!;
    } else {
      positionMs = 0;
    }

    final duration = Duration(milliseconds: positionMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;

    _minutesController = TextEditingController(text: minutes.toString());
    _secondsController = TextEditingController(text: seconds.toString());
    _millisecondsController = TextEditingController(text: milliseconds.toString().padLeft(3, '0'));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _millisecondsController.dispose();
    super.dispose();
  }

  /// Get the current position from time input fields
  int _getPositionMs() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final milliseconds = int.tryParse(_millisecondsController.text) ?? 0;

    return (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
  }

  /// Set the time fields to the current playback position
  void _setToCurrentPosition() {
    final playbackInfo = ref.read(currentPlaybackProvider);
    final position = playbackInfo.position;

    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    final milliseconds = position.inMilliseconds % 1000;

    setState(() {
      _minutesController.text = minutes.toString();
      _secondsController.text = seconds.toString();
      _millisecondsController.text = milliseconds.toString().padLeft(3, '0');
    });
  }

  Future<void> _saveMarker() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(markerRepositoryProvider);
      final now = DateTime.now().toUtc();
      final positionMs = _getPositionMs();

      if (widget.marker == null) {
        // Create new marker
        final marker = Marker(
          id: const Uuid().v4(),
          markerSetId: widget.markerSetId,
          label: _labelController.text.trim(),
          positionMs: positionMs,
          order: positionMs, // Order by position
          createdAt: now,
        );

        await repository.createMarker(marker);

        if (mounted) {
          // Invalidate the markers list to refresh it
          ref.invalidate(markersByMarkerSetProvider);

          // Show success message before closing
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marker created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pop(marker.id);
        }
      } else {
        // Update existing marker
        final updatedMarker = Marker(
          id: widget.marker!.id,
          markerSetId: widget.marker!.markerSetId,
          label: _labelController.text.trim(),
          positionMs: positionMs,
          order: positionMs, // Re-order by position
          createdAt: widget.marker!.createdAt,
        );

        final success = await repository.updateMarker(updatedMarker);

        if (mounted) {
          if (success) {
            // Invalidate the markers list to refresh it
            ref.invalidate(markersByMarkerSetProvider);
            ref.invalidate(markerByIdProvider);

            // Show success message before closing
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Marker updated successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            Navigator.of(context).pop(true);
          } else {
            throw Exception('Failed to update marker');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving marker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.marker != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Marker' : 'Add Marker'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label field
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g., Verse 1, Chorus, Bridge',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: !isEditing,
                enabled: !_isSaving,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a label';
                  }
                  if (value.trim().length < 2) {
                    return 'Label must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Position section
              Text(
                'Position',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),

              // Time input fields
              Row(
                children: [
                  // Minutes
                  Expanded(
                    child: TextFormField(
                      controller: _minutesController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      enabled: !_isSaving,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final minutes = int.tryParse(value);
                        if (minutes == null || minutes < 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(':', style: TextStyle(fontSize: 20)),
                  ),
                  // Seconds
                  Expanded(
                    child: TextFormField(
                      controller: _secondsController,
                      decoration: const InputDecoration(
                        labelText: 'Sec',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      enabled: !_isSaving,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final seconds = int.tryParse(value);
                        if (seconds == null || seconds < 0 || seconds >= 60) {
                          return '0-59';
                        }
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('.', style: TextStyle(fontSize: 20)),
                  ),
                  // Milliseconds
                  Expanded(
                    child: TextFormField(
                      controller: _millisecondsController,
                      decoration: const InputDecoration(
                        labelText: 'Ms',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      enabled: !_isSaving,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final ms = int.tryParse(value);
                        if (ms == null || ms < 0 || ms >= 1000) {
                          return '0-999';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // "Use current position" button
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _setToCurrentPosition,
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current Position'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveMarker,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
