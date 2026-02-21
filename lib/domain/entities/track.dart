import 'package:equatable/equatable.dart';

/// Represents an audio track for a song
/// Examples: "Soprano Part", "Full Choir", "Instrumental", "Practice Recording"
class Track extends Equatable {
  final String id;
  final String songId;
  final String name;

  /// Permanent public URL (legacy Supabase Storage; null for R2 tracks).
  final String? audioUrl;

  /// Object key in R2 (or Supabase Storage path for legacy tracks).
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
  /// (R2/cloud storage path, a legacy public URL, or a local file path).
  bool get hasAudio => storagePath != null || audioUrl != null || filePath != null;

  /// Returns the best available local/legacy audio source.
  /// Prefers audioUrl (legacy Supabase public URL), falls back to filePath.
  /// For R2 tracks, the signed URL is fetched at playback time via R2SignerClient.
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
