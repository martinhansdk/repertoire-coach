import 'package:equatable/equatable.dart';

/// Represents a user's playback position for a specific track
class UserPlaybackState extends Equatable {
  final String id; // Composite: userId_songId_trackId
  final String userId;
  final String songId;
  final String trackId;
  final int position; // Last playback position in milliseconds
  final DateTime updatedAt;

  const UserPlaybackState({
    required this.id,
    required this.userId,
    required this.songId,
    required this.trackId,
    required this.position,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        songId,
        trackId,
        position,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UserPlaybackState(id: $id, userId: $userId, trackId: $trackId, position: ${position}ms)';
  }
}
