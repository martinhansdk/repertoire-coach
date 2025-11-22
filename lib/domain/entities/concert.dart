import 'package:equatable/equatable.dart';

/// Concert domain entity
///
/// Represents a concert that belongs to a specific choir.
/// Concerts are automatically sorted by date (upcoming first, then past).
class Concert extends Equatable {
  final String id;
  final String choirId;
  final String choirName; // Denormalized for display convenience
  final String name;
  final DateTime concertDate;
  final DateTime createdAt;

  const Concert({
    required this.id,
    required this.choirId,
    required this.choirName,
    required this.name,
    required this.concertDate,
    required this.createdAt,
  });

  /// Returns true if this concert is in the future
  bool get isUpcoming => concertDate.isAfter(DateTime.now());

  /// Returns true if this concert is in the past
  bool get isPast => !isUpcoming;

  @override
  List<Object?> get props => [
        id,
        choirId,
        choirName,
        name,
        concertDate,
        createdAt,
      ];

  @override
  String toString() =>
      'Concert(id: $id, name: $name, date: $concertDate, choir: $choirName)';
}
