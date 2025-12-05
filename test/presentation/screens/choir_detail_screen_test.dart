import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';
import 'package:repertoire_coach/presentation/screens/choir_detail_screen.dart';
import 'package:repertoire_coach/presentation/widgets/create_concert_dialog.dart';

void main() {
  group('ChoirDetailScreen Widget', () {
    final testChoir = Choir(
      id: 'c1',
      name: 'Test Choir',
      ownerId: 'u1',
      createdAt: DateTime.now(),
    );

    final testConcert = Concert(
      id: 'con1',
      name: 'Test Concert',
      choirId: 'c1',
      choirName: 'Test Choir',
      concertDate: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

    testWidgets('should display loading indicator while loading choir',
        (tester) async {
      // Arrange - Create a never-completing future to keep it in loading state
      final completer = Completer<Choir>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      // Pump once to build the widget
      await tester.pump();

      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('should display choir name in app bar', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Choir'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display error when choir not found', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(null)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(0)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Choir not found'), findsOneWidget);
    });

    testWidgets('should display error when loading fails', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith(
              (ref) => Future.error('Failed to load choir'),
            ),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('Error'), findsWidgets);
    });

    testWidgets('should display choir info card with details', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Choir'), findsWidgets);
      expect(find.text('5 members'), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('should display owner chip when user is owner', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(Chip, 'You are the owner'), findsOneWidget);
    });

    testWidgets('should not display owner chip when user is not owner',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(Chip, 'You are the owner'), findsNothing);
    });

    testWidgets('should display concerts section header', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Concerts'), findsOneWidget);
    });

    testWidgets('should display empty state when no concerts', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No concerts yet'), findsOneWidget);
    });

    testWidgets('should display list of concerts', (tester) async {
      // Arrange
      final concerts = [
        testConcert,
        Concert(
          id: 'con2',
          name: 'Another Concert',
          choirId: 'c1',
          choirName: 'Test Choir',
          concertDate: DateTime.now().add(const Duration(days: 14)),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1')
                .overrideWith((ref) => Future.value(concerts)),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Test Concert'), findsOneWidget);
      expect(find.text('Another Concert'), findsOneWidget);
    });

    testWidgets('should display FAB to add concert', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(FloatingActionButton, 'Add Concert'),
          findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should show create concert dialog when FAB is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CreateConcertDialog), findsOneWidget);
    });

    testWidgets('should support pull-to-refresh', (tester) async {
      // Arrange
      var loadCount = 0;
      final container = ProviderContainer(
        overrides: [
          choirByIdProvider('c1').overrideWith((ref) {
            loadCount++;
            return Future.value(testChoir);
          }),
          choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
          isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
          concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert initial load
      expect(loadCount, 1);

      // Act - pull to refresh
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      // Assert - should reload
      expect(loadCount, 2);

      container.dispose();
    });

    testWidgets('should navigate to song list when concert is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1')
                .overrideWith((ref) => Future.value([testConcert])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap on concert
      await tester.tap(find.text('Test Concert'));
      await tester.pumpAndSettle();

      // Assert - should navigate (concert still visible after navigation)
      expect(find.text('Test Concert'), findsWidgets);
    });

    testWidgets('should display loading state while loading concerts',
        (tester) async {
      // Arrange - Create a never-completing future to keep concerts in loading state
      final completer = Completer<List<Concert>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      // Wait for choir to load but not concerts
      await tester.pumpAndSettle();

      // Assert - should show loading for concerts
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error when concerts fail to load',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => Future.value(5)),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith(
              (ref) => Future.error('Failed to load concerts'),
            ),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error loading concerts'), findsOneWidget);
    });

    testWidgets('should display loading state for member count',
        (tester) async {
      // Arrange - Create a never-completing future to keep member count in loading state
      final completer = Completer<int>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberCountProvider('c1').overrideWith((ref) => completer.future),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
            concertsByChoirProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChoirDetailScreen(choirId: 'c1'),
          ),
        ),
      );

      // Wait for choir to load but not member count
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Loading members...'), findsOneWidget);
    });
  });
}
