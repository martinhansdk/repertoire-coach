import 'package:drift/drift.dart';

import '../../domain/entities/choir.dart';
import '../datasources/local/database.dart' as db;

/// Choir data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class ChoirModel extends Choir {
  /// Whether this choir has been soft-deleted (for sync tracking)
  final bool deleted;

  const ChoirModel({
    required super.id,
    required super.name,
    required super.ownerId,
    required super.createdAt,
    required super.updatedAt,
    this.deleted = false,
  });

  /// Create a ChoirModel from a domain Choir entity
  factory ChoirModel.fromEntity(Choir choir) {
    return ChoirModel(
      id: choir.id,
      name: choir.name,
      ownerId: choir.ownerId,
      createdAt: choir.createdAt,
      updatedAt: choir.updatedAt,
      deleted: false,
    );
  }

  /// Convert to domain entity
  Choir toEntity() {
    return Choir(
      id: id,
      name: name,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a ChoirModel from a Drift database record
  factory ChoirModel.fromDrift(db.Choir driftChoir) {
    return ChoirModel(
      id: driftChoir.id,
      name: driftChoir.name,
      ownerId: driftChoir.ownerId,
      createdAt: driftChoir.createdAt,
      updatedAt: driftChoir.updatedAt,
      deleted: driftChoir.deleted,
    );
  }

  /// Convert to Drift companion for database writes
  db.ChoirsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.ChoirsCompanion(
      id: Value(id),
      name: Value(name),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  factory ChoirModel.fromJson(Map<String, dynamic> json) {
    final createdAtString = json['created_at'] as String;
    final updatedAtString = json['updated_at'] as String? ?? createdAtString;

    return ChoirModel(
      id: json['id'],
      name: json['name'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(createdAtString),
      updatedAt: DateTime.parse(updatedAtString),
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted': deleted,
    };
  }
}
