import 'package:equatable/equatable.dart';

/// Represents a user's favorite track with denormalized display data
///
/// This entity combines the favorite relationship (user + track) with
/// denormalized data from related entities (track name, song title, choir name)
/// to enable efficient display without additional queries.
class FavoriteTrack extends Equatable {
  /// User ID who favorited this track
  final String userId;

  /// ID of the favorited track
  final String trackId;

  /// ID of the song containing this track
  final String songId;

  /// When this track was added to favorites
  final DateTime addedAt;

  // Denormalized fields for display (from related entities)

  /// Name of the track (e.g., "Soprano Part", "Full Choir")
  final String trackName;

  /// Title of the song containing this track
  final String songTitle;

  /// Name of the choir this track belongs to
  final String choirName;

  /// Public URL to access the audio file (from Supabase Storage)
  final String? audioUrl;

  /// Duration of the audio file in milliseconds
  final int? durationMs;

  const FavoriteTrack({
    required this.userId,
    required this.trackId,
    required this.songId,
    required this.addedAt,
    required this.trackName,
    required this.songTitle,
    required this.choirName,
    this.audioUrl,
    this.durationMs,
  });

  /// Returns true if this track has an audio source available
  bool get hasAudio => audioUrl != null;

  @override
  List<Object?> get props => [
        userId,
        trackId,
        songId,
        addedAt,
        trackName,
        songTitle,
        choirName,
        audioUrl,
        durationMs,
      ];

  @override
  String toString() {
    return 'FavoriteTrack(userId: $userId, trackId: $trackId, songTitle: $songTitle, trackName: $trackName, choirName: $choirName)';
  }
}
