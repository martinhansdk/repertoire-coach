import '../../domain/entities/choir.dart';

/// Choir data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class ChoirModel extends Choir {
  const ChoirModel({
    required super.id,
    required super.name,
    required super.ownerId,
    required super.createdAt,
  });

  /// Create a ChoirModel from a domain Choir entity
  factory ChoirModel.fromEntity(Choir choir) {
    return ChoirModel(
      id: choir.id,
      name: choir.name,
      ownerId: choir.ownerId,
      createdAt: choir.createdAt,
    );
  }

  /// Convert to domain entity
  Choir toEntity() {
    return Choir(
      id: id,
      name: name,
      ownerId: ownerId,
      createdAt: createdAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
