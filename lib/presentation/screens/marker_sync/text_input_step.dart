import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    final text = _textController.text;
    ref.read(markerSyncNotifierProvider(widget.params).notifier).setLabels(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _textController.text;

    // Count lines and non-empty lines
    final lines = text.split('\n');
    final totalLines = lines.length;
    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
    final hasNonEmptyLines = nonEmptyLines > 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Helper text
          Text(
            'Enter one marker per line',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Examples: verse, chorus, intro, bridge, or lyrics',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Empty lines are preserved for visual spacing',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

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
              const Spacer(),
              // Show example button
              TextButton(
                key: const ValueKey('markerSyncLoadExampleButton'),
                onPressed: () {
                  _textController.text = 'intro\n\nverse 1\nchorus\n\nverse 2\nchorus\n\nbridge\n\nchorus\noutro';
                  setState(() {});
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high),
                    SizedBox(width: 8),
                    Text('Load Example'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Next button
          FilledButton(
            key: const ValueKey('markerSyncNextButton'),
            onPressed: hasNonEmptyLines ? _onNextPressed : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_forward),
                SizedBox(width: 8),
                Text('Next: Sync to Audio'),
              ],
            ),
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
    );
  }
}
