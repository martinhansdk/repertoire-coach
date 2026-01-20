import 'package:equatable/equatable.dart';

/// Represents an audio track for a song
/// Examples: "Soprano Part", "Full Choir", "Instrumental", "Practice Recording"
class Track extends Equatable {
  final String id;
  final String songId;
  final String name;

  /// Public URL to access the audio file (from Supabase Storage)
  final String? audioUrl;

  /// Path in Supabase Storage bucket (e.g., "choirs/{choir_id}/tracks/{track_id}.mp3")
  final String? storagePath;

  /// Duration of the audio file in milliseconds
  final int? durationMs;

  /// Local file path (legacy, for offline/temp use)
  final String? filePath;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Track({
    required this.id,
    required this.songId,
    required this.name,
    this.audioUrl,
    this.storagePath,
    this.durationMs,
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true if this track has an audio source available
  /// (either a cloud URL or local file path)
  bool get hasAudio => audioUrl != null || filePath != null;

  /// Returns the best available audio source URL
  /// Prefers audioUrl (cloud), falls back to filePath (local)
  String? get audioSource => audioUrl ?? filePath;

  @override
  List<Object?> get props => [
        id,
        songId,
        name,
        audioUrl,
        storagePath,
        durationMs,
        filePath,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Track(id: $id, songId: $songId, name: $name, audioUrl: $audioUrl)';
  }
}
