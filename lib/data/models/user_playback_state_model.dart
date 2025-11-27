import 'package:drift/drift.dart';
import '../../domain/entities/user_playback_state.dart';
import '../datasources/local/database.dart' as db;

/// UserPlaybackState data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class UserPlaybackStateModel extends UserPlaybackState {
  const UserPlaybackStateModel({
    required super.id,
    required super.userId,
    required super.songId,
    required super.trackId,
    required super.position,
    required super.updatedAt,
  });

  /// Create a UserPlaybackStateModel from a domain UserPlaybackState entity
  factory UserPlaybackStateModel.fromEntity(UserPlaybackState state) {
    return UserPlaybackStateModel(
      id: state.id,
      userId: state.userId,
      songId: state.songId,
      trackId: state.trackId,
      position: state.position,
      updatedAt: state.updatedAt,
    );
  }

  /// Convert to domain entity
  UserPlaybackState toEntity() {
    return UserPlaybackState(
      id: id,
      userId: userId,
      songId: songId,
      trackId: trackId,
      position: position,
      updatedAt: updatedAt,
    );
  }

  /// Create a UserPlaybackStateModel from a Drift database record
  factory UserPlaybackStateModel.fromDrift(db.UserPlaybackState driftState) {
    return UserPlaybackStateModel(
      id: driftState.id,
      userId: driftState.userId,
      songId: driftState.songId,
      trackId: driftState.trackId,
      position: driftState.position,
      updatedAt: driftState.updatedAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.UserPlaybackStatesCompanion toDriftCompanion() {
    return db.UserPlaybackStatesCompanion(
      id: Value(id),
      userId: Value(userId),
      songId: Value(songId),
      trackId: Value(trackId),
      position: Value(position),
      updatedAt: Value(updatedAt),
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
