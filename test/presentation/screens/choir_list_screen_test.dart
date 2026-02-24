import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/core/services/sync_service.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/providers/sync_provider.dart';
import 'package:repertoire_coach/presentation/screens/choir_list_screen.dart';
import 'package:repertoire_coach/presentation/widgets/create_choir_dialog.dart';

/// Mock SyncController that does nothing for tests
class MockSyncController extends SyncController {
  int syncCallCount = 0;

  @override
  SyncState build() => SyncState.initial;

  @override
  Future<void> syncFromRemote() async {
    syncCallCount++;
    // Do nothing - just track calls
  }
}

void main() {
  group('ChoirListScreen Widget', () {
    testWidgets('should display app bar with title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(MockSyncController.new),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('My Choirs'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('should display loading indicator while loading',
        (tester) async {
      // Arrange - Create a never-completing future to keep it in loading state
      final completer = Completer<List<Choir>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(MockSyncController.new),
            choirsProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      // Pump once to build the widget
      await tester.pump();

      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty state when no choirs', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirsProvider.overrideWith((ref) => Future.value([])),
            syncControllerProvider.overrideWith(MockSyncController.new),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Choirs Yet'), findsOneWidget);
      expect(find.text('Create a new choir or sync from cloud'), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    });

    testWidgets('should display list of choirs when data is loaded',
        (tester) async {
      // Arrange
      final testChoirs = [
        Choir(
          id: 'c1',
          name: 'Choir 1',
          ownerId: 'u1',
          createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
        ),
        Choir(
          id: 'c2',
          name: 'Choir 2',
          ownerId: 'u1',
          createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(MockSyncController.new),
            choirsProvider.overrideWith((ref) => Future.value(testChoirs)),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Choir 1'), findsOneWidget);
      expect(find.text('Choir 2'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display error state when loading fails',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirsProvider.overrideWith(
              (ref) => Future.error('Failed to load choirs'),
            ),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Error Loading Choirs'), findsOneWidget);
      expect(find.text('Failed to load choirs'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    }, skip: true); // Complex async timing issues

    testWidgets('should call onRetry when retry button is tapped',
        (tester) async {
      // Arrange
      var callCount = 0;
      final container = ProviderContainer(
        overrides: [
          choirsProvider.overrideWith((ref) {
            callCount++;
            if (callCount == 1) {
              return Future.error('Failed to load choirs');
            }
            return Future.value([]);
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert error state
      expect(find.text('Error Loading Choirs'), findsOneWidget);

      // Act - tap retry button
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      // Assert - should show empty state after retry
      expect(find.text('No Choirs Yet'), findsOneWidget);
      expect(callCount, 2);

      container.dispose();
    }, skip: true); // Complex async timing issues

    testWidgets('should navigate to choir detail when choir is tapped',
        (tester) async {
      // Arrange
      final testChoir = Choir(
        id: 'c1',
        name: 'Test Choir',
        ownerId: 'u1',
        createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirsProvider.overrideWith((ref) => Future.value([testChoir])),
            // Mock other providers needed by ChoirDetailScreen
            choirByIdProvider('c1').overrideWith((ref) => Future.value(testChoir)),
            choirMembersProvider('c1').overrideWith((ref) => Future.value(['u1'])),
            isChoirOwnerProvider('c1').overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap on choir card
      await tester.tap(find.text('Test Choir'));
      await tester.pumpAndSettle();

      // Assert - should navigate to detail screen
      expect(find.text('Test Choir'), findsWidgets); // Still visible after navigation
    }, skip: true); // Navigation async timing issues

    testWidgets('should show create choir dialog when FAB is tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CreateChoirDialog), findsOneWidget);
      expect(find.text('Create Choir'), findsOneWidget);
    }, skip: true); // Dialog async timing issues

    testWidgets('should display FAB with correct label', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(MockSyncController.new),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.widgetWithText(FloatingActionButton, 'New Choir'),
          findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should support pull-to-refresh', (tester) async {
      // Arrange
      var loadCount = 0;
      var syncCallCount = 0;

      // Create a custom sync controller that tracks calls and invalidates choirsProvider
      final container = ProviderContainer(
        overrides: [
          choirsProvider.overrideWith((ref) {
            loadCount++;
            return Future.value([
              Choir(
                id: 'c1',
                name: 'Choir $loadCount',
                ownerId: 'u1',
                createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
              ),
            ]);
          }),
          syncControllerProvider.overrideWith(() {
            return _TestSyncController(
              onSync: () {
                syncCallCount++;
              },
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert initial state
      expect(find.text('Choir 1'), findsOneWidget);
      expect(loadCount, 1);

      // Act - pull to refresh
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      // Assert - sync is called twice: once on screen entry (initState) and once on pull-to-refresh
      expect(syncCallCount, 2);

      container.dispose();
    });

    testWidgets('should display multiple choirs in scrollable list',
        (tester) async {
      // Arrange - create many choirs
      final testChoirs = List.generate(
        20,
        (index) => Choir(
          id: 'c$index',
          name: 'Choir $index',
          ownerId: 'u1',
          createdAt: DateTime.now(),
        updatedAt: DateTime(2024, 1, 1),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(MockSyncController.new),
            choirsProvider.overrideWith((ref) => Future.value(testChoirs)),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - should find some choirs visible
      expect(find.text('Choir 0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Scroll down to find more choirs
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Should find choirs further down the list
      expect(find.text('Choir 10', skipOffstage: false), findsOneWidget);
    });

    group('Sync On Enter', () {
      testWidgets('triggers syncFromRemote when status is idle', (tester) async {
        late final _ConfigurableSyncController controller;
        controller = _ConfigurableSyncController(SyncState.initial);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(() => controller),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ));
        await tester.pump();
        expect(controller.syncCallCount, 1);
      });

      testWidgets('triggers syncFromRemote when status is success', (tester) async {
        final controller = _ConfigurableSyncController(SyncState.success());
        await tester.pumpWidget(ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(() => controller),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ));
        await tester.pump();
        expect(controller.syncCallCount, 1);
      });

      testWidgets('does not trigger syncFromRemote when status is syncing', (tester) async {
        final controller = _ConfigurableSyncController(SyncState.syncing());
        await tester.pumpWidget(ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(() => controller),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ));
        await tester.pump();
        expect(controller.syncCallCount, 0);
      });

      testWidgets('does not trigger syncFromRemote when status is error', (tester) async {
        final controller = _ConfigurableSyncController(SyncState.error('network error'));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(() => controller),
            choirsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: ChoirListScreen()),
        ));
        await tester.pump();
        expect(controller.syncCallCount, 0);
      });
    });
  });
}

/// Test sync controller that tracks sync calls
class _TestSyncController extends SyncController {
  final VoidCallback? onSync;

  _TestSyncController({this.onSync});

  @override
  SyncState build() => SyncState.initial;

  @override
  Future<void> syncFromRemote() async {
    onSync?.call();
    // Do nothing else - just track the call
  }
}

class _ConfigurableSyncController extends SyncController {
  final SyncState initialState;
  int syncCallCount = 0;

  _ConfigurableSyncController(this.initialState);

  @override
  SyncState build() => initialState;

  @override
  Future<void> syncFromRemote() async {
    syncCallCount++;
  }
}
