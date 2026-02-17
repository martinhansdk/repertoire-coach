import 'package:equatable/equatable.dart';

/// Choir domain entity
///
/// Represents a group of users who share concerts and songs.
/// Choirs have an owner who manages membership.
class Choir extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Choir({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, name, ownerId, createdAt, updatedAt];

  @override
  String toString() => 'Choir(id: $id, name: $name, ownerId: $ownerId)';
}
