import '../../domain/entities/user_playback_state.dart';

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

  // Future: Add fromJson and toJson methods for Supabase
}
