/// Domain-specific exception for marker payload invariant violations.
class MarkerInvariantException implements Exception {
  final String developerMessage;

  const MarkerInvariantException(this.developerMessage);

  /// Safe message shown to users.
  static const String userMessage =
      'Could not save markers right now. Please restart marker sync and try again.';

  @override
  String toString() => developerMessage;
}
