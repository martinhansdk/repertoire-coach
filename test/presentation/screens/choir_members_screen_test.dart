import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/repositories/choir_repository.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/screens/choir_members_screen.dart';
import 'package:repertoire_coach/presentation/widgets/add_member_dialog.dart';

import 'choir_members_screen_test.mocks.dart';

@GenerateMocks([ChoirRepository])
void main() {
  group('ChoirMembersScreen Widget', () {
    final testChoir = Choir(
      id: 'c1',
      name: 'Test Choir',
      ownerId: 'owner123',
      createdAt: DateTime.now(),
    );

    testWidgets('should display app bar with title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Members'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading',
        (tester) async {
      // Arrange - Create a never-completing future to keep it in loading state
      final completer = Completer<List<String>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMembersProvider('c1').overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      // Pump once to build the widget
      await tester.pump();

      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up
      completer.complete(['owner123']);
      await tester.pumpAndSettle();
    });

    testWidgets('should display empty state when no members', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMembersProvider('c1').overrideWith((ref) => Future.value([])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No members'), findsOneWidget);
    });

    testWidgets('should display error state when loading fails',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMembersProvider('c1').overrideWith(
              (ref) => Future.error('Failed to load members'),
            ),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error: Failed to load members'), findsOneWidget);
    });

    testWidgets('should display list of members', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('owner123'), findsOneWidget);
      expect(find.text('member456'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('should display owner label for choir owner', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets('should display remove button for non-owners when user is owner',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - remove button should be visible for non-owner only
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('should not display remove button when user is not owner',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - no remove buttons should be visible
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('should display FAB to add member when user is owner',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(FloatingActionButton, 'Add Member'),
          findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('should not display FAB when user is not owner',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show add member dialog when FAB is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AddMemberDialog), findsOneWidget);
    });

    testWidgets('should show confirmation dialog when remove button is tapped',
        (tester) async {
      // Arrange
      final mockRepo = MockChoirRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap remove button
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Remove Member'), findsOneWidget);
      expect(find.textContaining('Remove member456'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Remove'), findsOneWidget);
    });

    testWidgets('should cancel remove when cancel button is tapped',
        (tester) async {
      // Arrange
      final mockRepo = MockChoirRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap remove button then cancel
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog should be closed, no repository call
      expect(find.text('Remove Member'), findsNothing);
      verifyNever(mockRepo.removeMember(any, any));
    });

    testWidgets('should remove member when confirmed', (tester) async {
      // Arrange
      final mockRepo = MockChoirRepository();
      when(mockRepo.removeMember('c1', 'member456'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap remove button and confirm
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      // Assert - should call removeMember and show success snackbar
      verify(mockRepo.removeMember('c1', 'member456')).called(1);
      expect(find.text('Member removed'), findsOneWidget);
    });

    testWidgets('should show error snackbar when remove fails', (tester) async {
      // Arrange
      final mockRepo = MockChoirRepository();
      when(mockRepo.removeMember('c1', 'member456'))
          .thenThrow(Exception('Failed to remove'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['owner123', 'member456'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap remove button and confirm
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      // Assert - should show error snackbar
      expect(find.textContaining('Error'), findsOneWidget);
    });

    testWidgets('should support pull-to-refresh', (tester) async {
      // Arrange
      var loadCount = 0;
      final container = ProviderContainer(
        overrides: [
          choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
          choirMembersProvider('c1').overrideWith((ref) {
            loadCount++;
            return Future.value(['owner123']);
          }),
          isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
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

    testWidgets('should display circle avatar with first letter',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1')
                .overrideWith((ref) => Future.value(['alice123'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });
  });
}
