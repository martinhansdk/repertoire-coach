import 'package:drift/drift.dart';

import '../../domain/entities/choir_member.dart';
import '../datasources/local/database.dart' as db;

/// Choir member data model
///
/// Extends the domain entity and adds serialization capabilities.
/// Handles conversions between domain entities, Drift database records,
/// and future JSON for Supabase integration.
class ChoirMemberModel extends ChoirMember {
  const ChoirMemberModel({
    required super.choirId,
    required super.userId,
    required super.joinedAt,
  });

  /// Create a ChoirMemberModel from a domain ChoirMember entity
  factory ChoirMemberModel.fromEntity(ChoirMember choirMember) {
    return ChoirMemberModel(
      choirId: choirMember.choirId,
      userId: choirMember.userId,
      joinedAt: choirMember.joinedAt,
    );
  }

  /// Convert to domain entity
  ChoirMember toEntity() {
    return ChoirMember(
      choirId: choirId,
      userId: userId,
      joinedAt: joinedAt,
    );
  }

  /// Create a ChoirMemberModel from a Drift database record
  factory ChoirMemberModel.fromDrift(db.ChoirMember driftChoirMember) {
    return ChoirMemberModel(
      choirId: driftChoirMember.choirId,
      userId: driftChoirMember.userId,
      joinedAt: driftChoirMember.joinedAt,
    );
  }

  /// Convert to Drift companion for database writes
  db.ChoirMembersCompanion toDriftCompanion({bool markForSync = true}) {
    return db.ChoirMembersCompanion(
      choirId: Value(choirId),
      userId: Value(userId),
      joinedAt: Value(joinedAt),
      synced: Value(!markForSync), // If markForSync=true, synced=false
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
