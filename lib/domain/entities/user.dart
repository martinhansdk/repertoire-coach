import 'package:equatable/equatable.dart';

/// Represents a user in the system
class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final List<String> choirIds;
  final String? lastAccessedConcertId;
  final String languagePreference;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.choirIds,
    this.lastAccessedConcertId,
    required this.languagePreference,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        choirIds,
        lastAccessedConcertId,
        languagePreference,
        createdAt,
      ];

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName, '
        'choirIds: $choirIds, lastAccessedConcertId: $lastAccessedConcertId, '
        'languagePreference: $languagePreference)';
  }
}
