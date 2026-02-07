import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/screens/marker_sync/marker_sync_state.dart';

void main() {
  group('MarkerSyncState', () {
    group('initial factory', () {
      test('creates state with correct defaults', () {
        final state = MarkerSyncState.initial(
          trackId: 'track-123',
          markerSetId: 'marker-set-456',
        );

        expect(state.step, SyncStep.textInput);
        expect(state.trackId, 'track-123');
        expect(state.markerSetId, 'marker-set-456');
        expect(state.labels, isEmpty);
        expect(state.syncedPositions, isEmpty);
        expect(state.currentIndex, -1);
        expect(state.isDirty, false);
      });

      test('creates state with empty IDs when not provided', () {
        final state = MarkerSyncState.initial();

        expect(state.trackId, '');
        expect(state.markerSetId, '');
      });
    });

    group('isComplete', () {
      test('returns false when no labels', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: [],
        );

        expect(state.isComplete, false);
      });

      test('returns false when no non-empty labels', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: ['', '', ''],
        );

        expect(state.isComplete, false);
      });

      test('returns true when current index is at last non-empty marker', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: ['verse', '', 'chorus'],
          currentIndex: 2, // At last non-empty marker
          syncedPositions: {-1: 0, 0: 1000, 2: 2000},
        );

        expect(state.isComplete, true);
      });

      test('returns true when current index is past last non-empty marker', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: ['verse', '', 'chorus'],
          currentIndex: 3, // Past last non-empty marker
          syncedPositions: {-1: 0, 0: 1000, 2: 2000},
        );

        expect(state.isComplete, true);
      });

      test('returns true when current index is past last marker with trailing empty lines', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: ['verse', 'chorus', '', ''],
          currentIndex: 2, // Past index 1 (last non-empty)
          syncedPositions: {-1: 0, 0: 1000, 1: 2000},
        );

        expect(state.isComplete, true);
      });

      test('returns false when some non-empty markers not synced', () {
        final state = MarkerSyncState.initial().copyWith(
          step: SyncStep.timeSync,
          labels: ['verse', 'chorus', 'bridge'],
          currentIndex: 1, // Only synced up to chorus
          syncedPositions: {-1: 0, 0: 1000, 1: 2000},
        );

        expect(state.isComplete, false);
      });
    });

    group('getPositionForIndex', () {
      test('returns position when marker is synced', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0, 0: 1000, 1: 2000},
        );

        expect(state.getPositionForIndex(-1), 0);
        expect(state.getPositionForIndex(0), 1000);
        expect(state.getPositionForIndex(1), 2000);
      });

      test('returns null when marker is not synced', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0, 0: 1000},
        );

        expect(state.getPositionForIndex(1), null);
        expect(state.getPositionForIndex(2), null);
        expect(state.getPositionForIndex(99), null);
      });

      test('handles negative indices (special "..." marker)', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0},
        );

        expect(state.getPositionForIndex(-1), 0);
      });
    });

    group('getLastSyncedPosition', () {
      test('returns 0 when no positions synced', () {
        final state = MarkerSyncState.initial();

        expect(state.getLastSyncedPosition(), 0);
      });

      test('returns highest position when one position synced', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0},
        );

        expect(state.getLastSyncedPosition(), 0);
      });

      test('returns highest position when multiple positions synced', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0, 0: 5000, 1: 10000, 2: 7500},
        );

        expect(state.getLastSyncedPosition(), 10000);
      });

      test('returns highest position even if markers synced out of order', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0, 0: 10000, 1: 5000, 2: 15000},
        );

        expect(state.getLastSyncedPosition(), 15000);
      });

      test('handles negative and zero positions', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {-1: 0, 0: 0, 1: 0},
        );

        expect(state.getLastSyncedPosition(), 0);
      });
    });

    group('copyWith', () {
      test('copies with new step', () {
        final original = MarkerSyncState.initial();
        final copy = original.copyWith(step: SyncStep.timeSync);

        expect(copy.step, SyncStep.timeSync);
        expect(copy.trackId, original.trackId);
        expect(copy.markerSetId, original.markerSetId);
      });

      test('copies with new labels', () {
        final original = MarkerSyncState.initial();
        final newLabels = ['verse', 'chorus'];
        final copy = original.copyWith(labels: newLabels);

        expect(copy.labels, newLabels);
        expect(copy.step, original.step);
      });

      test('copies with new synced positions', () {
        final original = MarkerSyncState.initial();
        final newPositions = {0: 1000, 1: 2000};
        final copy = original.copyWith(syncedPositions: newPositions);

        expect(copy.syncedPositions, newPositions);
        expect(copy.labels, original.labels);
      });

      test('copies with new current index', () {
        final original = MarkerSyncState.initial();
        final copy = original.copyWith(currentIndex: 5);

        expect(copy.currentIndex, 5);
      });

      test('copies with new isDirty flag', () {
        final original = MarkerSyncState.initial();
        final copy = original.copyWith(isDirty: true);

        expect(copy.isDirty, true);
        expect(original.isDirty, false);
      });

      test('preserves original values when not specified', () {
        final original = MarkerSyncState.initial(
          trackId: 'track-1',
          markerSetId: 'set-1',
        ).copyWith(
          labels: ['test'],
          syncedPositions: {0: 1000},
          currentIndex: 2,
          isDirty: true,
        );

        final copy = original.copyWith(step: SyncStep.timeSync);

        expect(copy.step, SyncStep.timeSync);
        expect(copy.trackId, 'track-1');
        expect(copy.markerSetId, 'set-1');
        expect(copy.labels, ['test']);
        expect(copy.syncedPositions, {0: 1000});
        expect(copy.currentIndex, 2);
        expect(copy.isDirty, true);
      });
    });

    group('Equatable', () {
      test('states with same values are equal', () {
        final state1 = MarkerSyncState(
          step: SyncStep.textInput,
          trackId: 'track-1',
          markerSetId: 'set-1',
          labels: const ['verse', 'chorus'],
          syncedPositions: const {0: 1000},
          currentIndex: 0,
          isDirty: false,
        );

        final state2 = MarkerSyncState(
          step: SyncStep.textInput,
          trackId: 'track-1',
          markerSetId: 'set-1',
          labels: const ['verse', 'chorus'],
          syncedPositions: const {0: 1000},
          currentIndex: 0,
          isDirty: false,
        );

        expect(state1, equals(state2));
      });

      test('states with different values are not equal', () {
        final state1 = MarkerSyncState.initial();
        final state2 = state1.copyWith(isDirty: true);

        expect(state1, isNot(equals(state2)));
      });

      test('states with different labels are not equal', () {
        final state1 = MarkerSyncState.initial().copyWith(labels: ['verse']);
        final state2 = MarkerSyncState.initial().copyWith(labels: ['chorus']);

        expect(state1, isNot(equals(state2)));
      });

      test('states with different synced positions are not equal', () {
        final state1 = MarkerSyncState.initial().copyWith(syncedPositions: {0: 1000});
        final state2 = MarkerSyncState.initial().copyWith(syncedPositions: {0: 2000});

        expect(state1, isNot(equals(state2)));
      });

      test('hashCode is consistent with equals', () {
        final state1 = MarkerSyncState.initial();
        final state2 = MarkerSyncState.initial();

        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('Edge Cases', () {
      test('handles state with very large position values', () {
        final state = MarkerSyncState.initial().copyWith(
          syncedPositions: {0: 999999999},
        );

        expect(state.getLastSyncedPosition(), 999999999);
        expect(state.getPositionForIndex(0), 999999999);
      });

      test('handles state with many labels', () {
        final manyLabels = List.generate(100, (i) => 'label-$i');
        final state = MarkerSyncState.initial().copyWith(
          labels: manyLabels,
          currentIndex: 50,
        );

        expect(state.labels.length, 100);
        expect(state.currentIndex, 50);
      });

      test('handles state with sparse synced positions', () {
        final state = MarkerSyncState.initial().copyWith(
          labels: ['a', 'b', 'c', 'd', 'e'],
          syncedPositions: {0: 1000, 2: 2000, 4: 3000}, // Skipped indices 1, 3
        );

        expect(state.getPositionForIndex(0), 1000);
        expect(state.getPositionForIndex(1), null);
        expect(state.getPositionForIndex(2), 2000);
        expect(state.getPositionForIndex(3), null);
        expect(state.getPositionForIndex(4), 3000);
      });
    });
  });
}
