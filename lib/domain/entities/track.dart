import 'package:equatable/equatable.dart';

/// Represents an audio track for a song
/// Examples: "Soprano", "Tenor", "Full Choir", "Instrumental", "Practice Recording"
class Track extends Equatable {
  final String id;
  final String songId;
  final String name;
  final String voicePart;
  final String? filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Track({
    required this.id,
    required this.songId,
    required this.name,
    required this.voicePart,
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        songId,
        name,
        voicePart,
        filePath,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Track(id: $id, songId: $songId, name: $name, voicePart: $voicePart)';
  }
}
