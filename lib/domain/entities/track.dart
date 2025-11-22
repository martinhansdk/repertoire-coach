import 'package:equatable/equatable.dart';

/// Represents an audio track for a song
/// Examples: "Soprano", "Tenor", "Full Choir", "Instrumental", "Practice Recording"
class Track extends Equatable {
  final String id;
  final String songId;
  final String name;
  final String audioUrl;
  final String? localPath;
  final int duration; // Duration in milliseconds
  final DateTime createdAt;

  const Track({
    required this.id,
    required this.songId,
    required this.name,
    required this.audioUrl,
    this.localPath,
    required this.duration,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        songId,
        name,
        audioUrl,
        localPath,
        duration,
        createdAt,
      ];

  @override
  String toString() {
    return 'Track(id: $id, songId: $songId, name: $name, duration: ${duration}ms)';
  }
}
