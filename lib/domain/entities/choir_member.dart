import 'package:equatable/equatable.dart';

/// Choir member domain entity
///
/// Represents the membership relationship between a user and a choir.
/// Used to track which users belong to which choirs and when they joined.
class ChoirMember extends Equatable {
  final String choirId;
  final String userId;
  final DateTime joinedAt;
  final DateTime updatedAt;

  const ChoirMember({
    required this.choirId,
    required this.userId,
    required this.joinedAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [choirId, userId, joinedAt, updatedAt];

  @override
  String toString() =>
      'ChoirMember(choirId: $choirId, userId: $userId, joinedAt: $joinedAt)';
}
