import 'package:drift/drift.dart';

import '../../domain/entities/concert.dart';
import '../datasources/local/database.dart' as db;

/// Concert data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
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

  /// Create a ConcertModel from a Drift database record
  factory ConcertModel.fromDrift(db.Concert driftConcert) {
    return ConcertModel(
      id: driftConcert.id,
      choirId: driftConcert.choirId,
      choirName: driftConcert.choirName,
      name: driftConcert.name,
      concertDate: driftConcert.concertDate,
      createdAt: driftConcert.createdAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.ConcertsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.ConcertsCompanion(
      id: Value(id),
      choirId: Value(choirId),
      choirName: Value(choirName),
      name: Value(name),
      concertDate: Value(concertDate),
      createdAt: Value(createdAt),
      updatedAt: Value(DateTime.now().toUtc()),
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase

  factory ConcertModel.fromJson(Map<String, dynamic> json) {
    return ConcertModel(
      id: json['id'],
      choirId: json['choir_id'],
      choirName: json['choir_name'],
      name: json['name'],
      concertDate: DateTime.parse(json['concert_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choir_id': choirId,
      'choir_name': choirName,
      'name': name,
      'concert_date': concertDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
