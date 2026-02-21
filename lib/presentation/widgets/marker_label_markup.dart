import 'package:flutter/material.dart';

/// Parsed representation of a marker label with simple line-leading markup.
///
/// Supported syntax:
/// - `#` at line start => bold
/// - `/` at line start => italic
class MarkerLabelMarkup {
  final String rawText;
  final String displayText;
  final bool isBold;
  final bool isItalic;

  const MarkerLabelMarkup({
    required this.rawText,
    required this.displayText,
    required this.isBold,
    required this.isItalic,
  });

  factory MarkerLabelMarkup.parse(String label, {required bool stripSyntax}) {
    if (label.isEmpty) {
      return const MarkerLabelMarkup(
        rawText: '',
        displayText: '',
        isBold: false,
        isItalic: false,
      );
    }

    final first = label[0];
    final isBold = first == '#';
    final isItalic = first == '/';
    if (!isBold && !isItalic) {
      return MarkerLabelMarkup(
        rawText: label,
        displayText: label,
        isBold: false,
        isItalic: false,
      );
    }

    if (!stripSyntax) {
      return MarkerLabelMarkup(
        rawText: label,
        displayText: label,
        isBold: isBold,
        isItalic: isItalic,
      );
    }

    final stripped = label.substring(1).replaceFirst(RegExp(r'^[ \t]+'), '');
    return MarkerLabelMarkup(
      rawText: label,
      displayText: stripped,
      isBold: isBold,
      isItalic: isItalic,
    );
  }

  TextStyle applyStyle(TextStyle? baseStyle, {bool emphasizeIfPlain = false}) {
    return (baseStyle ?? const TextStyle()).copyWith(
      fontWeight: isBold
          ? FontWeight.bold
          : (emphasizeIfPlain ? FontWeight.w600 : baseStyle?.fontWeight),
      fontStyle: isItalic ? FontStyle.italic : baseStyle?.fontStyle,
    );
  }
}

class MarkerMarkupTextEditingController extends TextEditingController {
  MarkerMarkupTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final parsed = MarkerLabelMarkup.parse(lines[i], stripSyntax: false);
      spans.add(
        TextSpan(
          text: parsed.displayText,
          style: parsed.applyStyle(style),
        ),
      );
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: style));
      }
    }

    return TextSpan(style: style, children: spans);
  }
}
