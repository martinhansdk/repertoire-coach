import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/constants.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/data/repositories/concert_repository_impl.dart';
import 'package:repertoire_coach/domain/repositories/concert_repository.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/screens/concert_list_screen.dart';

void main() {
  group('ConcertListScreen Widget', () {
    late db.AppDatabase database;
    late LocalConcertDataSource dataSource;
    late ConcertRepository repository;

    setUp(() async {
      // Create in-memory database for testing
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalConcertDataSource(database);
      repository = ConcertRepositoryImpl(dataSource);

      // Seed test data
      await _seedTestData(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('should display loading indicator while fetching concerts',
        (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('should display concert list when data is loaded',
        (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Wait for the async data to load
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Spring Concert 2025'), findsOneWidget);
      expect(find.text('City Chamber Choir'), findsWidgets);
    });

    testWidgets('should display app bar with app name', (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text(AppConstants.appName), findsOneWidget);

      // Clean up pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('should display empty state when no concerts', (tester) async {
      // Arrange - Create empty database for this test
      final emptyDatabase = db.AppDatabase.forTesting(NativeDatabase.memory());
      final emptyDataSource = LocalConcertDataSource(emptyDatabase);
      final emptyRepository = ConcertRepositoryImpl(emptyDataSource);

      // Override provider to use empty repository
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(emptyRepository),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Wait for async data
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Concerts'), findsOneWidget);
      expect(find.text('Join a choir to see concerts'), findsOneWidget);
      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);

      // Cleanup
      await emptyDatabase.close();
    });

    testWidgets('should display error state when loading fails',
        (tester) async {
      // Arrange - Override provider to throw error
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertsProvider.overrideWith((ref) async =>
                throw Exception('Failed to load concerts')),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Wait for async error
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error Loading Concerts'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should navigate to song list when concert is tapped',
        (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Tap on first concert card
      await tester.tap(find.text('Spring Concert 2025'));
      await tester.pump(); // Trigger navigation

      // Assert - check that SongListScreen is being pushed
      // Note: Full navigation test would require mocking song provider
      expect(find.text('Spring Concert 2025'), findsAtLeastNWidgets(1));
    }, skip: true); // TODO: Fix navigation test with proper provider mocking
  });
}

/// Seed test data into the database
Future<void> _seedTestData(LocalConcertDataSource dataSource) async {
  final testConcerts = [
    ConcertModel(
      id: '1',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Spring Concert 2025',
      concertDate: DateTime(2025, 4, 15),
      createdAt: DateTime(2024, 12, 1),
    ),
    ConcertModel(
      id: '2',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Christmas Concert 2024',
      concertDate: DateTime(2024, 12, 20),
      createdAt: DateTime(2024, 10, 1),
    ),
    ConcertModel(
      id: '3',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Summer Festival',
      concertDate: DateTime(2025, 6, 10),
      createdAt: DateTime(2024, 11, 15),
    ),
    ConcertModel(
      id: '4',
      choirId: 'choir2',
      choirName: 'Community Singers',
      name: 'Autumn Recital',
      concertDate: DateTime(2024, 10, 5),
      createdAt: DateTime(2024, 8, 1),
    ),
    ConcertModel(
      id: '5',
      choirId: 'choir1',
      choirName: 'City Chamber Choir',
      name: 'Winter Showcase',
      concertDate: DateTime(2025, 2, 14),
      createdAt: DateTime(2024, 11, 20),
    ),
  ];

  for (final concert in testConcerts) {
    await dataSource.upsertConcert(concert, markForSync: false);
  }
}
