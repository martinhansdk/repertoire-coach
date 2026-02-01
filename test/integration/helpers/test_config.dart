/// Integration test configuration
///
/// Contains test credentials, test data identifiers, and configuration
/// for integration test scenarios.
library;

/// Test account credentials
/// These should match a real test account in Supabase
class TestCredentials {
  static const String email = 'repertoireclaude@gmail.com';
  static const String password = 'frunky-gump-12';
}

/// Known test data identifiers
/// These should exist in the test account's data
class TestData {
  // Choir names
  static const String testChoirName = 'Bad Choir';

  // Concert names
  static const String testConcertName = 'Bad fest 2026';

  // Song names
  static const String testSongName = 'Really bad song';

  // Track names (tracks with audio files)
  static const String testTrackWithAudio = 'Off key group track';
}

/// Timeouts for various operations
class TestTimeouts {
  /// Time to wait for network operations (sign in, sync)
  static const Duration networkOperation = Duration(seconds: 10);

  /// Time to wait for navigation animations
  static const Duration navigation = Duration(milliseconds: 500);

  /// Time to wait for audio to start playing
  static const Duration audioStart = Duration(seconds: 3);

  /// Time to wait for UI to settle after state changes
  static const Duration uiSettle = Duration(milliseconds: 300);
}
