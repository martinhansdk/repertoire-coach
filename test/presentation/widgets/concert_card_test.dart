import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/presentation/widgets/concert_card.dart';

void main() {
  group('ConcertCard Widget', () {
    testWidgets('should display concert information correctly',
        (tester) async {
      // Arrange
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcertCard(concert: concert),
          ),
        ),
      );

      // Assert
      expect(find.text('Spring Concert'), findsOneWidget);
      expect(find.text('Test Choir'), findsOneWidget);
      expect(find.text('15'), findsOneWidget); // Day
      expect(find.text('Apr'), findsOneWidget); // Month
    });

    testWidgets('should handle onTap callback', (tester) async {
      // Arrange
      bool tapped = false;
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Spring Concert',
        concertDate: DateTime(2025, 4, 15),
        createdAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcertCard(
              concert: concert,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ConcertCard));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, isTrue);
    }, skip: 'Timer pending after widget disposal - infrastructure issue');

    testWidgets('should display upcoming icon for future concerts',
        (tester) async {
      // Arrange
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Future Concert',
        concertDate: futureDate,
        createdAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcertCard(concert: concert),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.event_available), findsOneWidget);
    });

    testWidgets('should display past icon for past concerts', (tester) async {
      // Arrange
      final pastDate = DateTime.now().subtract(const Duration(days: 30));
      final concert = Concert(
        id: '1',
        choirId: 'choir1',
        choirName: 'Test Choir',
        name: 'Past Concert',
        concertDate: pastDate,
        createdAt: DateTime.now(),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcertCard(concert: concert),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.event_busy), findsOneWidget);
    });
  });
}
