import 'package:equatable/equatable.dart';

import 'track.dart';

/// Represents a user's favorite track
///
/// A minimal entity that combines a Track with the timestamp when it was favorited.
/// User context is implicit (from authentication), and related data (song, concert, choir)
/// can be looked up via the Track's relationships.
class FavoriteTrack extends Equatable {
  /// When this track was added to favorites
  final DateTime addedAt;

  /// The full Track object with all track data
  ///
  /// Contains: id, songId, name, audioUrl, storagePath, durationMs, etc.
  /// Use track.songId to look up the parent Song.
  final Track track;

  const FavoriteTrack({
    required this.addedAt,
    required this.track,
  });

  /// Returns true if this track has an audio source available
  bool get hasAudio => track.hasAudio;

  @override
  List<Object?> get props => [
        addedAt,
        track,
      ];

  @override
  String toString() {
    return 'FavoriteTrack(addedAt: $addedAt, track: ${track.name})';
  }
}
