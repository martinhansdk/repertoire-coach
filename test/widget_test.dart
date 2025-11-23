import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/constants.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/main.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create in-memory database for testing
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final dataSource = LocalConcertDataSource(database);
    final repository = ConcertRepositoryImpl(dataSource);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
        ],
        child: const RepertoireCoachApp(),
      ),
    );

    // Verify that the app bar title is present
    expect(find.text(AppConstants.appName), findsOneWidget);

    // Verify that a loading indicator or concert list appears
    // (depending on timing, we might see loading or the actual list)
    await tester.pumpAndSettle();

    // After settling, we should see empty state (no test data seeded)
    expect(find.text('No Concerts'), findsOneWidget);
    expect(find.text('Join a choir to see concerts'), findsOneWidget);

    // Cleanup
    await database.close();
  });
}
