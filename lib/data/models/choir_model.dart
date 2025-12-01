import 'package:drift/drift.dart';

import '../../domain/entities/choir.dart';
import '../datasources/local/database.dart' as db;

/// Choir data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
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

  /// Create a ChoirModel from a Drift database record
  factory ChoirModel.fromDrift(db.Choir driftChoir) {
    return ChoirModel(
      id: driftChoir.id,
      name: driftChoir.name,
      ownerId: driftChoir.ownerId,
      createdAt: driftChoir.createdAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.ChoirsCompanion toDriftCompanion({bool markForSync = true}) {
    return db.ChoirsCompanion(
      id: Value(id),
      name: Value(name),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
      updatedAt: Value(DateTime.now().toUtc()),
      deleted: const Value(false),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase

  factory ChoirModel.fromJson(Map<String, dynamic> json) {
    return ChoirModel(
      id: json['id'],
      name: json['name'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
