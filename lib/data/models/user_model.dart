import '../../domain/entities/user.dart';

/// User data model
///
/// Extends the domain entity and adds serialization capabilities.
/// For now, this is a simple extension. In future, this will handle
/// JSON serialization/deserialization for Supabase integration.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.displayName,
    required super.choirIds,
    super.lastAccessedConcertId,
    required super.languagePreference,
    required super.createdAt,
  });

  /// Create a UserModel from a domain User entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      choirIds: user.choirIds,
      lastAccessedConcertId: user.lastAccessedConcertId,
      languagePreference: user.languagePreference,
      createdAt: user.createdAt,
    );
  }

  /// Convert to domain entity
  User toEntity() {
    return User(
      id: id,
      email: email,
      displayName: displayName,
      choirIds: choirIds,
      lastAccessedConcertId: lastAccessedConcertId,
      languagePreference: languagePreference,
      createdAt: createdAt,
    );
  }

  // Future: Add fromJson and toJson methods for Supabase
}
