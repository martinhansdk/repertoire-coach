import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing the selected marker set ID.
///
/// Use this to track and update which marker set is currently displayed.
///
/// Example usage:
/// ```dart
/// // Get the selected marker set ID
/// final selectedId = ref.watch(selectedMarkerSetProvider);
///
/// // Update the selected marker set
/// ref.read(selectedMarkerSetProvider.notifier).state = 'marker-set-id';
///
/// // Clear selection
/// ref.read(selectedMarkerSetProvider.notifier).state = null;
/// ```
final selectedMarkerSetProvider = StateProvider<String?>((ref) => null);
