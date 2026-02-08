import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/presentation/providers/selected_marker_set_provider.dart';

void main() {
  group('selectedMarkerSetProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is null', () {
      expect(container.read(selectedMarkerSetProvider), isNull);
    });

    test('updates the selected marker set ID', () {
      // Arrange
      const markerSetId = 'marker-set-123';

      // Act
      container.read(selectedMarkerSetProvider.notifier).state = markerSetId;

      // Assert
      expect(container.read(selectedMarkerSetProvider), markerSetId);
    });

    test('can update to different marker set IDs', () {
      // Arrange
      const firstId = 'marker-set-1';
      const secondId = 'marker-set-2';
      const thirdId = 'marker-set-3';

      // Act & Assert
      container.read(selectedMarkerSetProvider.notifier).state = firstId;
      expect(container.read(selectedMarkerSetProvider), firstId);

      container.read(selectedMarkerSetProvider.notifier).state = secondId;
      expect(container.read(selectedMarkerSetProvider), secondId);

      container.read(selectedMarkerSetProvider.notifier).state = thirdId;
      expect(container.read(selectedMarkerSetProvider), thirdId);
    });

    test('can be cleared by setting null', () {
      // Arrange
      const markerSetId = 'marker-set-123';
      container.read(selectedMarkerSetProvider.notifier).state = markerSetId;

      // Act
      container.read(selectedMarkerSetProvider.notifier).state = null;

      // Assert
      expect(container.read(selectedMarkerSetProvider), isNull);
    });
  });
}
