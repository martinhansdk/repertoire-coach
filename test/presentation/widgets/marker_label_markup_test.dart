import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/widgets/marker_label_markup.dart';

void main() {
  group('MarkerLabelMarkup', () {
    test('strips leading syntax character and following whitespace for display mode', () {
      final bold = MarkerLabelMarkup.parse('#   Chorus', stripSyntax: true);
      final italic = MarkerLabelMarkup.parse('/\tVerse', stripSyntax: true);

      expect(bold.displayText, 'Chorus');
      expect(bold.isBold, isTrue);
      expect(bold.isItalic, isFalse);

      expect(italic.displayText, 'Verse');
      expect(italic.isBold, isFalse);
      expect(italic.isItalic, isTrue);
    });

    test('keeps syntax characters in edit mode parsing', () {
      final parsed = MarkerLabelMarkup.parse('# Intro', stripSyntax: false);

      expect(parsed.displayText, '# Intro');
      expect(parsed.isBold, isTrue);
      expect(parsed.isItalic, isFalse);
    });
  });

  group('MarkerMarkupTextEditingController', () {
    testWidgets('renders styled spans while keeping syntax characters visible', (tester) async {
      final controller = MarkerMarkupTextEditingController(
        text: '# Chorus\n/ Verse',
      );
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final rootSpan = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      final spans = rootSpan.children!.whereType<TextSpan>().toList();

      final firstLine = spans.firstWhere((span) => span.text == '# Chorus');
      final secondLine = spans.firstWhere((span) => span.text == '/ Verse');

      expect(firstLine.style?.fontWeight, FontWeight.bold);
      expect(secondLine.style?.fontStyle, FontStyle.italic);
    });
  });
}
