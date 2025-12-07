import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the currently selected marker set for a track
///
/// This tracks which marker set is currently displayed in the UI for
/// a specific track. When a user selects a different marker set from
/// the dropdown, this class provides methods to update the selection.
class SelectedMarkerSetNotifier {
  String? _selectedMarkerSetId;

  /// Get the currently selected marker set ID
  String? get selectedMarkerSetId => _selectedMarkerSetId;

  /// Set the selected marker set ID
  void select(String? markerSetId) {
    _selectedMarkerSetId = markerSetId;
  }

  /// Clear the selection
  void clear() {
    _selectedMarkerSetId = null;
  }
}

/// Provider for managing the selected marker set
///
/// Use this to track and update which marker set is currently displayed.
///
/// Example usage:
/// ```dart
/// // Get the selected marker set ID
/// final selectedId = ref.read(selectedMarkerSetProvider).selectedMarkerSetId;
///
/// // Update the selected marker set
/// ref.read(selectedMarkerSetProvider).select('marker-set-id');
///
/// // Clear selection
/// ref.read(selectedMarkerSetProvider).clear();
/// ```
final selectedMarkerSetProvider = Provider<SelectedMarkerSetNotifier>((ref) {
  return SelectedMarkerSetNotifier();
});
