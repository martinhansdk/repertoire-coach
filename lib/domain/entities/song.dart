import 'package:equatable/equatable.dart';

/// Represents a song in a concert
class Song extends Equatable {
  final String id;
  final String concertId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Song({
    required this.id,
    required this.concertId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        concertId,
        title,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Song(id: $id, concertId: $concertId, title: $title)';
  }
}
