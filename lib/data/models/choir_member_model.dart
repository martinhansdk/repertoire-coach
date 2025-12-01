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

  factory ChoirMemberModel.fromJson(Map<String, dynamic> json) {
    return ChoirMemberModel(
      choirId: json['choir_id'],
      userId: json['user_id'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choir_id': choirId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
