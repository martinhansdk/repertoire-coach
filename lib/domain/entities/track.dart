import 'package:equatable/equatable.dart';

/// Represents an audio track for a song
/// Examples: "Soprano Part", "Full Choir", "Instrumental", "Practice Recording"
class Track extends Equatable {
  final String id;
  final String songId;
  final String name;
  final String? filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Track({
    required this.id,
    required this.songId,
    required this.name,
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        songId,
        name,
        filePath,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Track(id: $id, songId: $songId, name: $name)';
  }
}
