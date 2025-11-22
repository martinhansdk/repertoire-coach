import '../../domain/entities/song.dart';

/// Song data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class SongModel extends Song {
  const SongModel({
    required super.id,
    required super.concertId,
    required super.title,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a SongModel from a domain Song entity
  factory SongModel.fromEntity(Song song) {
    return SongModel(
      id: song.id,
      concertId: song.concertId,
      title: song.title,
      createdAt: song.createdAt,
      updatedAt: song.updatedAt,
    );
  }

  /// Convert to domain entity
  Song toEntity() {
    return Song(
      id: id,
      concertId: concertId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
