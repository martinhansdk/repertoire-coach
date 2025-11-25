import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/widgets/create_concert_dialog.dart';

void main() {
  group('CreateConcertDialog Widget', () {
    late db.AppDatabase database;

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('should display dialog with required fields', (tester) async {
      // Arrange
      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreateConcertDialog(
                        choirId: 'choir1',
                        choirName: 'Test Choir',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Create New Concert'), findsOneWidget);
      expect(find.text('Concert Name'), findsOneWidget);
      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('should validate empty concert name', (tester) async {
      // Arrange
      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreateConcertDialog(
                        choirId: 'choir1',
                        choirName: 'Test Choir',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Try to create without entering name
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Assert - validation error should appear
      expect(find.text('Please enter a concert name'), findsOneWidget);
    });

    testWidgets('should validate concert name length', (tester) async {
      // Arrange
      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreateConcertDialog(
                        choirId: 'choir1',
                        choirName: 'Test Choir',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Enter a name that's too short
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Concert Name'),
        'A',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text('Concert name must be at least 2 characters'),
        findsOneWidget,
      );
    });

    testWidgets('should show date selector when tapping date button',
        (tester) async {
      // Arrange
      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreateConcertDialog(
                        choirId: 'choir1',
                        choirName: 'Test Choir',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap the date selector button
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      // Assert - date picker should be shown
      expect(find.text('Select Concert Date'), findsOneWidget);
    });

    testWidgets('should close dialog when Cancel is tapped', (tester) async {
      // Arrange
      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CreateConcertDialog(
                        choirId: 'choir1',
                        choirName: 'Test Choir',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Concert'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog should be closed
      expect(find.text('Create New Concert'), findsNothing);
    });
  });
}
