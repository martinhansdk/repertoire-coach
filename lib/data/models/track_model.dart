import '../../domain/entities/track.dart';

/// Track data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class TrackModel extends Track {
  const TrackModel({
    required super.id,
    required super.songId,
    required super.name,
    required super.audioUrl,
    super.localPath,
    required super.duration,
    required super.createdAt,
  });

  /// Create a TrackModel from a domain Track entity
  factory TrackModel.fromEntity(Track track) {
    return TrackModel(
      id: track.id,
      songId: track.songId,
      name: track.name,
      audioUrl: track.audioUrl,
      localPath: track.localPath,
      duration: track.duration,
      createdAt: track.createdAt,
    );
  }

  /// Convert to domain entity
  Track toEntity() {
    return Track(
      id: id,
      songId: songId,
      name: name,
      audioUrl: audioUrl,
      localPath: localPath,
      duration: duration,
      createdAt: createdAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
