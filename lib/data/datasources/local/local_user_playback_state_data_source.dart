import '../../models/user_playback_state_model.dart';
import 'database.dart' as db;

/// Local data source for user playback state operations using Drift/SQLite
///
/// Provides save and retrieve operations for playback positions.
/// All operations work offline. Playback states are per-user, per-track.
class LocalUserPlaybackStateDataSource {
  final db.AppDatabase _database;

  LocalUserPlaybackStateDataSource(this._database);

  /// Get playback state for a specific user and track
  ///
  /// Returns null if no saved position exists for this track.
  Future<UserPlaybackStateModel?> getPlaybackState(
    String userId,
    String trackId,
  ) async {
    final state = await _database.getPlaybackStateByUserAndTrack(
      userId,
      trackId,
    );
    return state != null ? UserPlaybackStateModel.fromDrift(state) : null;
  }

  /// Save (upsert) playback state for a user and track
  ///
  /// Creates a new record if none exists, otherwise updates existing record.
  /// This is the main method for saving playback positions.
  Future<void> savePlaybackState(UserPlaybackStateModel state) async {
    await _database.into(_database.userPlaybackStates).insertOnConflictUpdate(
          state.toDriftCompanion(),
        );
  }

  /// Delete playback state for a specific user and track
  ///
  /// Useful for clearing saved positions, e.g., when track finishes playing.
  Future<void> deletePlaybackState(String userId, String trackId) async {
    final compositeId = '${userId}_$trackId';
    await (_database.delete(_database.userPlaybackStates)
          ..where((s) => s.id.equals(compositeId)))
        .go();
  }

  /// Clear all playback states for a specific user
  ///
  /// Useful for testing or user data reset.
  Future<void> clearAllForUser(String userId) async {
    await (_database.delete(_database.userPlaybackStates)
          ..where((s) => s.userId.equals(userId)))
        .go();
  }

  /// Clear all playback state data (for testing)
  ///
  /// Permanently deletes all playback states. Use with caution!
  Future<void> clearAll() async {
    await _database.delete(_database.userPlaybackStates).go();
  }
}
