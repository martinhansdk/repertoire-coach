import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/marker_provider.dart';
import '../../providers/marker_sync_provider.dart';

/// Step 1 of marker sync: User inputs text (one marker per line)
class TextInputStep extends ConsumerStatefulWidget {
  final MarkerSyncParams params;

  const TextInputStep({super.key, required this.params});

  @override
  ConsumerState<TextInputStep> createState() => _TextInputStepState();
}

class _TextInputStepState extends ConsumerState<TextInputStep> {
  final _textController = TextEditingController();
  bool _didPrefill = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onNextPressed() async {
    final text = _textController.text;
    await ref
        .read(markerSyncNotifierProvider(widget.params).notifier)
        .startSyncFromText(text);
  }

  Future<void> _onSavePressed() async {
    final text = _textController.text;
    final saved = await ref
        .read(markerSyncNotifierProvider(widget.params).notifier)
        .saveTextOnly(text);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one non-empty line')),
      );
      return;
    }
    ref.invalidate(markersByMarkerSetProvider);
    ref.invalidate(markerSetByIdProvider);
    ref.invalidate(markerSetsByTrackProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markersAsync = ref.watch(markersByMarkerSetProvider(widget.params.markerSetId));
    final text = _textController.text;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    markersAsync.whenData((markers) {
      if (_didPrefill || _textController.text.isNotEmpty) {
        return;
      }
      if (markers.isEmpty) {
        return;
      }

      final sortedMarkers = List.of(markers)
        ..sort((a, b) => a.order.compareTo(b.order));
      final prefillText = sortedMarkers.map((marker) => marker.label).join('\n');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didPrefill) return;
        _textController.text = prefillText;
        _didPrefill = true;
        setState(() {});
      });
    });

    // Count lines and non-empty lines
    final lines = text.split('\n');
    final totalLines = lines.length;
    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
    final hasNonEmptyLines = nonEmptyLines > 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text input field
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'intro\nverse 1\nchorus\nverse 2\nchorus\nbridge\nchorus\noutro',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  helperText: 'Press the button below when done, or paste from clipboard',
                ),
                onChanged: (_) => setState(() {}), // Rebuild to update counter
              ),
            ),

            const SizedBox(height: 16),

            // Line counter
            Row(
              children: [
                Icon(
                  Icons.list_alt,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalLines lines ($nonEmptyLines non-empty)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Save / time sync actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('markerSyncSaveTextButton'),
                    onPressed: hasNonEmptyLines ? _onSavePressed : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('markerSyncNextButton'),
                    onPressed: hasNonEmptyLines ? _onNextPressed : null,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Time Sync'),
                  ),
                ),
              ],
            ),

            // Warning if no non-empty lines
            if (!hasNonEmptyLines && text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Please enter at least one non-empty line',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
