/// Widget test helpers
///
/// Common utilities for finding widgets, waiting for conditions,
/// and interacting with the UI in integration tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_config.dart';

/// Wait for a widget matching [finder] to appear
///
/// Pumps frames until the widget is found or [timeout] is reached.
/// Returns true if found, false if timed out.
Future<bool> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }

  return false;
}

/// Wait for a widget matching [finder] to disappear
Future<bool> waitForWidgetToDisappear(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) {
      return true;
    }
  }

  return false;
}

/// Wait for any loading indicators to disappear
Future<void> waitForLoading(WidgetTester tester) async {
  await waitForWidgetToDisappear(
    tester,
    find.byType(CircularProgressIndicator),
    timeout: TestTimeouts.networkOperation,
  );
  // Use fixed duration pump instead of pumpAndSettle to avoid
  // timeout issues with ongoing streams
  await tester.pump(const Duration(milliseconds: 500));
}

/// Find a text field by its label or hint text
Finder findTextField(String labelOrHint) {
  return find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      final decoration = widget.decoration;
      if (decoration != null) {
        final labelText = decoration.labelText;
        final hintText = decoration.hintText;
        return labelText == labelOrHint || hintText == labelOrHint;
      }
    }
    return false;
  });
}

/// Find a TextFormField by its label or hint text
///
/// Note: TextFormField doesn't expose decoration directly, so we search
/// for InputDecorator widgets that contain the label text.
Finder findTextFormField(String labelOrHint) {
  return find.byWidgetPredicate((widget) {
    if (widget is InputDecorator) {
      final decoration = widget.decoration;
      final labelText = decoration.labelText;
      final hintText = decoration.hintText;
      return labelText == labelOrHint || hintText == labelOrHint;
    }
    return false;
  });
}

/// Find a button (ElevatedButton, TextButton, etc.) by its text
Finder findButtonByText(String text) {
  return find.widgetWithText(ElevatedButton, text).first.evaluate().isNotEmpty
      ? find.widgetWithText(ElevatedButton, text)
      : find.widgetWithText(TextButton, text).first.evaluate().isNotEmpty
          ? find.widgetWithText(TextButton, text)
          : find.widgetWithText(FilledButton, text).first.evaluate().isNotEmpty
              ? find.widgetWithText(FilledButton, text)
              : find.widgetWithText(OutlinedButton, text);
}

/// Find a ListTile by its title text
Finder findListTileByTitle(String title) {
  return find.widgetWithText(ListTile, title);
}

/// Find an IconButton by its icon
Finder findIconButton(IconData icon) {
  return find.widgetWithIcon(IconButton, icon);
}

/// Tap on a widget and wait for the UI to update
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  // Use fixed duration pump instead of pumpAndSettle
  await tester.pump(const Duration(milliseconds: 500));
}

/// Enter text into a field and wait for the UI to update
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  // Use fixed duration pump instead of pumpAndSettle
  await tester.pump(const Duration(milliseconds: 300));
}

/// Scroll until a widget is visible
Future<bool> scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
  double delta = -100,
  int maxScrolls = 20,
}) async {
  scrollable ??= find.byType(Scrollable).first;

  for (var i = 0; i < maxScrolls; i++) {
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await tester.drag(scrollable, Offset(0, delta));
    // Use fixed duration pump instead of pumpAndSettle
    await tester.pump(const Duration(milliseconds: 300));
  }

  return finder.evaluate().isNotEmpty;
}

/// Print the current widget tree for debugging
void debugPrintWidgetTree(WidgetTester tester) {
  debugPrint('=== WIDGET TREE ===');
  debugPrint(tester.binding.rootElement!.toStringDeep());
  debugPrint('===================');
}

/// Print all text widgets for debugging
void debugPrintAllText(WidgetTester tester) {
  debugPrint('=== ALL TEXT WIDGETS ===');
  final textWidgets = find.byType(Text).evaluate();
  for (final element in textWidgets) {
    final text = element.widget as Text;
    debugPrint('Text: "${text.data}"');
  }
  debugPrint('========================');
}
