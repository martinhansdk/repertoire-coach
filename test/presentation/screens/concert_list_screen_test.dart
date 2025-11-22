import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/constants.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/screens/concert_list_screen.dart';

void main() {
  group('ConcertListScreen Widget', () {
    testWidgets('should display loading indicator while fetching concerts',
        (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display concert list when data is loaded',
        (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
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
        const ProviderScope(
          child: MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Assert
      expect(find.text(AppConstants.appName), findsOneWidget);
    });

    testWidgets('should display empty state when no concerts', (tester) async {
      // Arrange - Override provider to return empty list
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            concertsProvider.overrideWith((ref) async => []),
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

    testWidgets('should show snackbar when concert is tapped',
        (tester) async {
      // Act
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ConcertListScreen(),
          ),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Tap on first concert card
      await tester.tap(find.text('Spring Concert 2025'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Tapped: Spring Concert 2025'), findsOneWidget);
    });
  });
}
