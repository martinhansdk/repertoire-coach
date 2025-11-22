import '../../domain/entities/concert.dart';

/// Concert data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class ConcertModel extends Concert {
  const ConcertModel({
    required super.id,
    required super.choirId,
    required super.choirName,
    required super.name,
    required super.concertDate,
    required super.createdAt,
  });

  /// Create a ConcertModel from a domain Concert entity
  factory ConcertModel.fromEntity(Concert concert) {
    return ConcertModel(
      id: concert.id,
      choirId: concert.choirId,
      choirName: concert.choirName,
      name: concert.name,
      concertDate: concert.concertDate,
      createdAt: concert.createdAt,
    );
  }

  /// Convert to domain entity
  Concert toEntity() {
    return Concert(
      id: id,
      choirId: choirId,
      choirName: choirName,
      name: name,
      concertDate: concertDate,
      createdAt: createdAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
