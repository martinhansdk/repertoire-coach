import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/constants.dart';
import 'package:repertoire_coach/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RepertoireCoachApp(),
      ),
    );

    // Verify that the app bar title is present
    expect(find.text(AppConstants.appName), findsOneWidget);

    // Verify that a loading indicator or concert list appears
    // (depending on timing, we might see loading or the actual list)
    await tester.pumpAndSettle();

    // After settling, we should see concerts or empty state
    final hasConcerts = find.text('Spring Concert 2025').evaluate().isNotEmpty;
    final hasEmptyState = find.text('No Concerts').evaluate().isNotEmpty;

    expect(hasConcerts || hasEmptyState, isTrue);
  });
}
