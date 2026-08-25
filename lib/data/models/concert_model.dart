import 'package:drift/drift.dart';

import '../../domain/entities/concert.dart';
import '../datasources/local/database.dart' as db;

/// Concert data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class ConcertModel extends Concert {
  /// When this record was last updated (for sync timestamp comparison)
  final DateTime updatedAt;

  /// Whether this concert has been soft-deleted (for sync tracking)
  final bool deleted;

  const ConcertModel({
    required super.id,
    required super.choirId,
    required super.choirName,
    required super.name,
    required super.concertDate,
    required super.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// Create a ConcertModel from a domain Concert entity
  factory ConcertModel.fromEntity(Concert concert, {DateTime? updatedAt}) {
    return ConcertModel(
      id: concert.id,
      choirId: concert.choirId,
      choirName: concert.choirName,
      name: concert.name,
      concertDate: concert.concertDate,
      createdAt: concert.createdAt,
      updatedAt: updatedAt ?? concert.createdAt,
      deleted: false,
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
      updatedAt: driftConcert.updatedAt,
      deleted: driftConcert.deleted,
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
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  factory ConcertModel.fromJson(Map<String, dynamic> json) {
    return ConcertModel(
      id: json['id'],
      choirId: json['choir_id'],
      choirName: json['choir_name'],
      name: json['name'],
      concertDate: DateTime.parse(json['concert_date']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.parse(json['created_at']),
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choir_id': choirId,
      // Note: choir_name is NOT included - it's derived from joining with choirs table
      'name': name,
      'concert_date': concertDate.toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }
}
