import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/providers/selected_marker_set_provider.dart';

void main() {
  group('SelectedMarkerSetNotifier', () {
    late ProviderContainer container;
    late SelectedMarkerSetNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(selectedMarkerSetProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is null', () {
      // Assert
      expect(notifier.selectedMarkerSetId, isNull);
    });

    test('select() updates the selected marker set ID', () {
      // Arrange
      const markerSetId = 'marker-set-123';

      // Act
      notifier.select(markerSetId);

      // Assert
      expect(notifier.selectedMarkerSetId, markerSetId);
    });

    test('select() can update to different marker set IDs', () {
      // Arrange
      const firstId = 'marker-set-1';
      const secondId = 'marker-set-2';
      const thirdId = 'marker-set-3';

      // Act & Assert
      notifier.select(firstId);
      expect(notifier.selectedMarkerSetId, firstId);

      notifier.select(secondId);
      expect(notifier.selectedMarkerSetId, secondId);

      notifier.select(thirdId);
      expect(notifier.selectedMarkerSetId, thirdId);
    });

    test('select() can be called with null', () {
      // Arrange
      const markerSetId = 'marker-set-123';
      notifier.select(markerSetId);

      // Act
      notifier.select(null);

      // Assert
      expect(notifier.selectedMarkerSetId, isNull);
    });

    test('clear() resets selection to null', () {
      // Arrange
      const markerSetId = 'marker-set-123';
      notifier.select(markerSetId);

      // Act
      notifier.clear();

      // Assert
      expect(notifier.selectedMarkerSetId, isNull);
    });

    test('selectedMarkerSetProvider returns SelectedMarkerSetNotifier instance', () {
      expect(notifier, isA<SelectedMarkerSetNotifier>());
    });

    test('multiple reads from provider return same instance', () {
      // Act
      final notifier1 = container.read(selectedMarkerSetProvider);
      final notifier2 = container.read(selectedMarkerSetProvider);

      // Assert
      expect(notifier1, same(notifier2));
    });

    test('state persists across multiple reads', () {
      // Arrange
      const markerSetId = 'marker-set-456';

      // Act
      container.read(selectedMarkerSetProvider).select(markerSetId);
      final result = container.read(selectedMarkerSetProvider).selectedMarkerSetId;

      // Assert
      expect(result, markerSetId);
    });
  });
}
