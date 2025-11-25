import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/widgets/edit_concert_dialog.dart';

void main() {
  group('EditConcertDialog Widget', () {
    late db.AppDatabase database;

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('should display dialog with concert data pre-filled',
        (tester) async {
      // Arrange
      final concert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert 2025',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);

      // Seed the concert
      await dataSource.insertConcert(ConcertModel.fromEntity(concert));

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
                      builder: (context) => EditConcertDialog(concert: concert),
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

      // Assert
      expect(find.text('Edit Concert'), findsOneWidget);
      expect(find.text('Spring Concert 2025'), findsOneWidget);
      expect(find.textContaining('Apr 15, 2025'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should validate empty concert name', (tester) async {
      // Arrange
      final concert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);
      await dataSource.insertConcert(ConcertModel.fromEntity(concert));

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
                      builder: (context) => EditConcertDialog(concert: concert),
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

      // Clear the name field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Concert Name'),
        '',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Please enter a concert name'), findsOneWidget);
    });

    testWidgets('should validate concert name length', (tester) async {
      // Arrange
      final concert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

      final dataSource = LocalConcertDataSource(database);
      final repository = ConcertRepositoryImpl(dataSource);
      await dataSource.insertConcert(ConcertModel.fromEntity(concert));

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
                      builder: (context) => EditConcertDialog(concert: concert),
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
        'X',
      );
      await tester.tap(find.text('Save'));
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
      final concert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

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
                      builder: (context) => EditConcertDialog(concert: concert),
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
      await tester.tap(find.textContaining('Date:'));
      await tester.pumpAndSettle();

      // Assert - date picker should be shown
      expect(find.text('Select Concert Date'), findsOneWidget);
    });

    testWidgets('should close dialog when Cancel is tapped', (tester) async {
      // Arrange
      final concert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

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
                      builder: (context) => EditConcertDialog(concert: concert),
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

      expect(find.text('Edit Concert'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog should be closed
      expect(find.text('Edit Concert'), findsNothing);
    });

    testWidgets('should display upcoming/past status based on date',
        (tester) async {
      // Arrange - future concert
      final futureConcert = Concert(
        id: 'test-concert',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Future Concert',
        concertDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
      );

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
                      builder: (context) =>
                          EditConcertDialog(concert: futureConcert),
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

      // Assert
      expect(find.text('Upcoming concert'), findsOneWidget);
    });
  });
}
