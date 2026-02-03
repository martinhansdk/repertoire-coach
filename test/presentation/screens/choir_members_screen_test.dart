import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/repositories/choir_repository.dart';
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
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

    final ownerProfile = MemberProfile(
      userId: 'owner123',
      email: 'owner@example.com',
      displayName: 'Alice Owner',
    );

    final memberProfile = MemberProfile(
      userId: 'member456',
      email: 'member@example.com',
      displayName: 'Bob Member',
    );

    testWidgets('should display app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([ownerProfile])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Members'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading',
        (tester) async {
      final completer = Completer<List<MemberProfile>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty state when no members', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No members'), findsOneWidget);
    });

    testWidgets('should display error state when loading fails',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.error('Failed to load members'),
            ),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Error: Failed to load members'), findsOneWidget);
    });

    testWidgets('should display list of members with names and emails',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice Owner'), findsOneWidget);
      expect(find.text('Bob Member'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('should display owner label with email for choir owner',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Owner · owner@example.com'), findsOneWidget);
      expect(find.text('member@example.com'), findsOneWidget);
    });

    testWidgets('should display remove button for non-owners when user is owner',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Remove button visible only for the non-owner member
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('should not display remove button when user is not owner',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1')
                .overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('should display FAB to add member when user is owner',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([ownerProfile])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.widgetWithText(FloatingActionButton, 'Add Member'),
          findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('should not display FAB when user is not owner',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([ownerProfile])),
            isChoirOwnerProvider('c1')
                .overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should show add member dialog when FAB is tapped',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([ownerProfile])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AddMemberDialog), findsOneWidget);
    });

    testWidgets('should show confirmation dialog when remove button is tapped',
        (tester) async {
      final mockRepo = MockChoirRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove Member'), findsOneWidget);
      expect(find.textContaining('Remove Bob Member'), findsOneWidget);
      expect(find.textContaining('member@example.com'), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Remove'), findsOneWidget);
    });

    testWidgets('should cancel remove when cancel button is tapped',
        (tester) async {
      final mockRepo = MockChoirRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Member'), findsNothing);
      verifyNever(mockRepo.removeMember(any, any));
    });

    testWidgets('should remove member when confirmed', (tester) async {
      final mockRepo = MockChoirRepository();
      when(mockRepo.removeMember('c1', 'member456'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      verify(mockRepo.removeMember('c1', 'member456')).called(1);
      expect(find.text('Member removed'), findsOneWidget);
    });

    testWidgets('should show error snackbar when remove fails', (tester) async {
      final mockRepo = MockChoirRepository();
      when(mockRepo.removeMember('c1', 'member456'))
          .thenThrow(Exception('Failed to remove'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1').overrideWith(
              (ref) => Future.value([ownerProfile, memberProfile]),
            ),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
            choirRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error'), findsOneWidget);
    });

    testWidgets('should support pull-to-refresh', (tester) async {
      var loadCount = 0;
      final container = ProviderContainer(
        overrides: [
          choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
          choirMemberProfilesProvider('c1').overrideWith((ref) {
            loadCount++;
            return Future.value([ownerProfile]);
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

      expect(loadCount, 1);

      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(loadCount, 2);

      container.dispose();
    });

    testWidgets('should display circle avatar with first letter of name',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMemberProfilesProvider('c1')
                .overrideWith((ref) => Future.value([ownerProfile])),
            isChoirOwnerProvider('c1')
                .overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: ChoirMembersScreen(choirId: 'c1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // 'A' from 'Alice Owner'
    });
  });
}
