import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/domain/repositories/marker_repository.dart';
import 'package:repertoire_coach/presentation/providers/marker_sync_provider.dart';
import 'package:repertoire_coach/presentation/screens/marker_sync/marker_sync_state.dart';

@GenerateMocks([MarkerRepository])
import 'marker_sync_provider_test.mocks.dart';

void main() {
  group('MarkerSyncNotifier', () {
    late MockMarkerRepository mockRepository;
    late MarkerSyncNotifier notifier;
    late MarkerSet markerSet;

    setUp(() {
      mockRepository = MockMarkerRepository();
      markerSet = MarkerSet(
        id: 'set-1',
        trackId: 'track-1',
        name: 'Test Set',
        isShared: false,
        isTimeSynced: false,
        createdByUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      notifier = MarkerSyncNotifier(
        markerRepository: mockRepository,
        trackId: 'track-1',
        markerSetId: 'set-1',
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    group('setLabels', () {
      test('should parse text into labels and advance to timeSync step', () {
        const text = 'intro\nverse 1\nchorus';

        notifier.setLabels(text);

        expect(notifier.state.step, SyncStep.timeSync);
        expect(notifier.state.labels, ['intro', 'verse 1', 'chorus']);
        expect(notifier.state.currentIndex, -1);
        expect(notifier.state.syncedPositions, {-1: 0}); // "..." marker
        expect(notifier.state.isDirty, false);
      });

      test('should preserve empty lines for visual spacing', () {
        const text = 'intro\n\nverse 1\n\nchorus';

        notifier.setLabels(text);

        expect(notifier.state.labels, ['intro', '', 'verse 1', '', 'chorus']);
      });

      test('should trim whitespace from each line', () {
        const text = '  intro  \n  verse 1  \n  chorus  ';

        notifier.setLabels(text);

        expect(notifier.state.labels, ['intro', 'verse 1', 'chorus']);
      });

      test('should not advance if all lines are empty', () {
        const text = '\n\n\n';

        notifier.setLabels(text);

        expect(notifier.state.step, SyncStep.textInput);
        expect(notifier.state.labels, []);
      });

      test('should handle single non-empty line', () {
        const text = 'intro';

        notifier.setLabels(text);

        expect(notifier.state.step, SyncStep.timeSync);
        expect(notifier.state.labels, ['intro']);
      });
    });

    group('startSyncFromText', () {
      test('should persist unsynced markers and advance to timeSync', () async {
        when(mockRepository.deleteMarkersByMarkerSet(any)).thenAnswer((_) async => {});
        when(mockRepository.createMarker(any)).thenAnswer((_) async => {});
        when(mockRepository.getMarkersByMarkerSet(any)).thenAnswer((_) async => []);
        when(mockRepository.getMarkerSetById(any)).thenAnswer((_) async => markerSet);
        when(mockRepository.updateMarkerSet(any)).thenAnswer((_) async => true);

        await notifier.startSyncFromText('intro\n\nverse');

        final captured = verify(mockRepository.createMarker(captureAny)).captured;
        expect(captured.length, 3);

        final markers = captured.cast<Marker>();
        expect(markers[0].label, 'intro');
        expect(markers[0].positionMs, 0);
        expect(markers[1].label, '');
        expect(markers[2].label, 'verse');

        verify(mockRepository.updateMarkerSet(argThat(
          isA<MarkerSet>().having((ms) => ms.isTimeSynced, 'isTimeSynced', false),
        ))).called(1);

        expect(notifier.state.step, SyncStep.timeSync);
        expect(notifier.state.labels, ['intro', '', 'verse']);
      });
    });

    group('syncNextMarker', () {
      setUp(() {
        notifier.setLabels('intro\nverse\nchorus');
      });

      test('should sync next non-empty marker and advance highlight', () {
        notifier.syncNextMarker(1000);

        expect(notifier.state.currentIndex, 0);
        expect(notifier.state.syncedPositions[0], 1000);
        expect(notifier.state.isDirty, true);
      });

      test('should skip empty lines when syncing', () {
        notifier = MarkerSyncNotifier(
          markerRepository: mockRepository,
          trackId: 'track-1',
          markerSetId: 'set-1',
        );
        notifier.setLabels('intro\n\n\nverse');

        notifier.syncNextMarker(1000);

        expect(notifier.state.currentIndex, 0); // intro
        expect(notifier.state.syncedPositions[0], 1000);
        expect(notifier.state.syncedPositions[1], null);
        expect(notifier.state.syncedPositions[2], null);

        notifier.syncNextMarker(2000);

        expect(notifier.state.currentIndex, 3); // verse (skipped 2 empty lines)
        expect(notifier.state.syncedPositions[1], 2000);
        expect(notifier.state.syncedPositions[2], 2000);
        expect(notifier.state.syncedPositions[3], 2000);
      });

      test('should enforce monotonic invariant (prevent backward sync)', () {
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);

        // Try to sync at earlier position - should be rejected
        notifier.syncNextMarker(500);

        expect(notifier.state.currentIndex, 1); // Still at second marker
        expect(notifier.state.syncedPositions[2], null); // Third not synced
      });

      test('should allow syncing at same position as last', () {
        notifier.syncNextMarker(1000);

        notifier.syncNextMarker(1000); // Same position

        expect(notifier.state.currentIndex, 1);
        expect(notifier.state.syncedPositions[1], 1000);
      });

      test('should do nothing when all markers synced', () {
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);
        notifier.syncNextMarker(3000);

        // Try to sync again - should do nothing
        final stateBefore = notifier.state;
        notifier.syncNextMarker(4000);

        expect(notifier.state, stateBefore);
      });

      test('should invalidate later markers when syncing from earlier index', () {
        notifier.syncNextMarker(1000); // intro
        notifier.syncNextMarker(2000); // verse
        notifier.syncNextMarker(3000); // chorus

        notifier.jumpToMarker(0); // back to intro
        notifier.syncNextMarker(1500); // resync from earlier point

        expect(notifier.state.currentIndex, 1); // verse synced next
        expect(notifier.state.syncedPositions[0], 1000);
        expect(notifier.state.syncedPositions[1], 1500);
        expect(notifier.state.syncedPositions[2], null);
      });
    });

    group('getLastSyncedPosition', () {
      setUp(() {
        notifier.setLabels('intro\nverse\nchorus');
      });

      test('should return 0 when only "..." marker synced', () {
        expect(notifier.state.getLastSyncedPosition(), 0);
      });

      test('should return highest synced position', () {
        notifier.syncNextMarker(1000);
        expect(notifier.state.getLastSyncedPosition(), 1000);

        notifier.syncNextMarker(2500);
        expect(notifier.state.getLastSyncedPosition(), 2500);

        notifier.syncNextMarker(2000); // Rejected by monotonic check
        expect(notifier.state.getLastSyncedPosition(), 2500);
      });
    });

    group('jumpToMarker', () {
      setUp(() {
        notifier.setLabels('intro\nverse\nchorus');
      });

      test('should jump to specified marker without applying position', () {
        notifier.jumpToMarker(1);

        expect(notifier.state.currentIndex, 1);
        expect(notifier.state.syncedPositions[1], null); // Not synced
      });

      test('should allow jumping to "..." marker', () {
        notifier.syncNextMarker(1000);
        notifier.jumpToMarker(-1);

        expect(notifier.state.currentIndex, -1);
      });

      test('should ignore invalid indices', () {
        final stateBefore = notifier.state;

        notifier.jumpToMarker(-2); // Too low
        expect(notifier.state, stateBefore);

        notifier.jumpToMarker(999); // Too high
        expect(notifier.state, stateBefore);
      });
    });

    group('restart', () {
      setUp(() {
        notifier.setLabels('intro\nverse\nchorus');
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);
      });

      test('should clear all positions except "..." and reset to start', () {
        notifier.restart();

        expect(notifier.state.currentIndex, -1);
        expect(notifier.state.syncedPositions, {-1: 0});
        expect(notifier.state.isDirty, true);
      });

      test('should keep labels intact', () {
        final labelsBefore = notifier.state.labels;

        notifier.restart();

        expect(notifier.state.labels, labelsBefore);
      });
    });

    group('save', () {
      setUp(() {
        notifier.setLabels('intro\n\nverse\nchorus\noutro');
        when(mockRepository.getMarkerSetById(any)).thenAnswer((_) async => markerSet);
        when(mockRepository.updateMarkerSet(any)).thenAnswer((_) async => true);
        when(mockRepository.deleteMarkersByMarkerSet(any)).thenAnswer((_) async => {});
      });

      test('should save markers (including empty and unsynced)', () async {
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(3000);
        notifier.syncNextMarker(5000);

        when(mockRepository.createMarker(any)).thenAnswer((_) async => {});

        await notifier.save();

        // Should create 5 markers (including empty and unsynced)
        final captured = verify(mockRepository.createMarker(captureAny)).captured;
        expect(captured.length, 5);

        final markers = captured.cast<Marker>();
        expect(markers[0].label, 'intro');
        expect(markers[0].positionMs, 1000);
        expect(markers[1].label, '');
        expect(markers[1].positionMs, 3000);
        expect(markers[2].label, 'verse');
        expect(markers[2].positionMs, 3000);
        expect(markers[3].label, 'chorus');
        expect(markers[3].positionMs, 5000);
        expect(markers[4].label, 'outro');
        expect(markers[4].positionMs, 0);

        verify(mockRepository.updateMarkerSet(argThat(
          isA<MarkerSet>().having((ms) => ms.isTimeSynced, 'isTimeSynced', false),
        ))).called(1);
      });

      test('should preserve marker display order from input', () async {
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);

        when(mockRepository.createMarker(any)).thenAnswer((_) async => {});

        await notifier.save();

        final captured = verify(mockRepository.createMarker(captureAny)).captured;
        final markers = captured.cast<Marker>();

        expect(markers[0].order, 0);
        expect(markers[2].order, 2);
      });

      test('should mark state as not dirty after save', () async {
        notifier.syncNextMarker(1000);
        when(mockRepository.createMarker(any)).thenAnswer((_) async => {});

        expect(notifier.state.isDirty, true);

        await notifier.save();

        expect(notifier.state.isDirty, false);
      });

      test('marks marker set as time synced when all non-empty markers are synced', () async {
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);
        notifier.syncNextMarker(3000);
        notifier.syncNextMarker(4000);

        when(mockRepository.createMarker(any)).thenAnswer((_) async => {});

        await notifier.save();

        verify(mockRepository.updateMarkerSet(argThat(
          isA<MarkerSet>().having((ms) => ms.isTimeSynced, 'isTimeSynced', true),
        ))).called(1);
      });
    });

    group('discard', () {
      setUp(() {
        notifier.setLabels('intro\nverse');
        notifier.syncNextMarker(1000);
      });

      test('should reset to initial state', () {
        notifier.discard();

        expect(notifier.state.step, SyncStep.textInput);
        expect(notifier.state.labels, []);
        expect(notifier.state.syncedPositions, {});
        expect(notifier.state.currentIndex, -1);
      });
    });

    group('isComplete', () {
      test('should be false when no non-empty markers', () {
        notifier.setLabels('\n\n');

        expect(notifier.state.isComplete, false);
      });

      test('should be false when not all non-empty markers synced', () {
        notifier.setLabels('intro\nverse\nchorus');
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);

        expect(notifier.state.isComplete, false);
      });

      test('should be true when all non-empty markers synced', () {
        notifier.setLabels('intro\nverse\nchorus');
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);
        notifier.syncNextMarker(3000);

        expect(notifier.state.isComplete, true);
      });

      test('should ignore trailing empty lines', () {
        notifier.setLabels('intro\nverse\n\n\n');
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(2000);

        expect(notifier.state.isComplete, true);
      });
    });
  });
}
