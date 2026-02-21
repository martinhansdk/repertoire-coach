import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'platform_view_registry_stub.dart'
    if (dart.library.html) 'platform_view_registry_web.dart' as platform_view_registry;

class WebInputField extends StatefulWidget {
  final String label;
  final String inputType;
  final String autocomplete;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const WebInputField({
    super.key,
    required this.label,
    required this.inputType,
    required this.autocomplete,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<WebInputField> createState() => _WebInputFieldState();
}

class _WebInputFieldState extends State<WebInputField> {
  static int _nextId = 0;
  late final String _viewType;
  html.InputElement? _input;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-input-${_nextId++}';
    if (!kIsWeb) {
      return;
    }

    final input = html.InputElement()
      ..type = widget.inputType
      ..autocomplete = widget.autocomplete
      ..placeholder = widget.label
      ..disabled = !widget.enabled
      ..style.width = '100%'
      ..style.height = '48px'
      ..style.padding = '12px 14px'
      ..style.fontSize = '16px'
      ..style.borderRadius = '8px'
      ..style.border = '1px solid #b9b9b9'
      ..style.boxSizing = 'border-box'
      ..style.backgroundColor = '#ffffff'
      ..style.color = '#111111';
    input.onInput.listen((_) {
      widget.onChanged(input.value ?? '');
    });
    _input = input;

    platform_view_registry.registerWebViewFactory(_viewType, (int viewId) => input);
  }

  @override
  void didUpdateWidget(covariant WebInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_input != null) {
      _input!.disabled = !widget.enabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: HtmlElementView(viewType: _viewType),
        ),
      ],
    );
  }
}
