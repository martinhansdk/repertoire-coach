import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/screens/home_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create in-memory database for testing
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final dataSource = LocalConcertDataSource(database);
    final repository = ConcertRepositoryImpl(dataSource);

    // Build HomeScreen directly (offline mode)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Pump a few frames to let the app build
    await tester.pump();

    // Verify that bottom navigation is present
    expect(find.text('Choirs'), findsOneWidget);
    expect(find.text('Concerts'), findsOneWidget);

    // Cleanup
    await database.close();
  });
}
