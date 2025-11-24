import 'package:drift/drift.dart';
import 'database_connection.dart';

part 'database.g.dart';

/// Table definition for choirs
class Choirs extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// Name of the choir
  TextColumn get name => text()();

  /// ID of the user who owns this choir
  TextColumn get ownerId => text()();

  /// When this record was created
  DateTimeColumn get createdAt => dateTime()();

  /// When this record was last updated (for sync)
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete flag (true = deleted, false = active)
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table definition for choir membership (many-to-many relationship)
class ChoirMembers extends Table {
  /// ID of the choir
  TextColumn get choirId => text()();

  /// ID of the user who is a member
  TextColumn get userId => text()();

  /// When the user joined this choir
  DateTimeColumn get joinedAt => dateTime()();

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {choirId, userId};
}

/// Table definition for concerts
class Concerts extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// ID of the choir this concert belongs to
  TextColumn get choirId => text()();

  /// Name of the choir (denormalized for performance)
  TextColumn get choirName => text()();

  /// Concert name/title
  TextColumn get name => text()();

  /// Date of the concert
  DateTimeColumn get concertDate => dateTime()();

  /// When this record was created
  DateTimeColumn get createdAt => dateTime()();

  /// When this record was last updated (for sync)
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete flag (true = deleted, false = active)
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main application database
@DriftDatabase(tables: [Choirs, ChoirMembers, Concerts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  /// Migration strategy for database upgrades
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1 && to == 2) {
            // Add Choirs and ChoirMembers tables
            await m.createTable(choirs);
            await m.createTable(choirMembers);

            // Create indexes for performance
            await customStatement(
              'CREATE INDEX idx_choir_members_user ON choir_members(user_id)',
            );
            await customStatement(
              'CREATE INDEX idx_choir_members_choir ON choir_members(choir_id)',
            );
          }
        },
      );

  /// Get all active (non-deleted) concerts, sorted by date
  ///
  /// Sorts concerts with upcoming concerts first (soonest to farthest),
  /// followed by past concerts (most recent to oldest).
  Future<List<Concert>> getAllConcerts() async {
    final all = await (select(concerts)..where((c) => c.deleted.equals(false)))
        .get();

    // Sort in Dart rather than SQL for complex date-based sorting
    return _sortConcertsByDate(all);
  }

  /// Watch all active concerts (reactive stream), sorted by date
  Stream<List<Concert>> watchAllConcerts() {
    return (select(concerts)..where((c) => c.deleted.equals(false)))
        .watch()
        .map(_sortConcertsByDate);
  }

  /// Sort concerts by date: upcoming first (ascending), then past (descending)
  List<Concert> _sortConcertsByDate(List<Concert> concerts) {
    final now = DateTime.now();
    final sorted = List<Concert>.from(concerts)
      ..sort((a, b) {
        final aIsUpcoming = a.concertDate.isAfter(now);
        final bIsUpcoming = b.concertDate.isAfter(now);

        // Both upcoming: sort ascending (soonest first)
        if (aIsUpcoming && bIsUpcoming) {
          return a.concertDate.compareTo(b.concertDate);
        }

        // Both past: sort descending (most recent first)
        if (!aIsUpcoming && !bIsUpcoming) {
          return b.concertDate.compareTo(a.concertDate);
        }

        // One upcoming, one past: upcoming comes first
        return aIsUpcoming ? -1 : 1;
      });

    return sorted;
  }

  /// Get concert by ID
  Future<Concert?> getConcertById(String id) {
    return (select(concerts)
          ..where((c) => c.id.equals(id))
          ..where((c) => c.deleted.equals(false)))
        .getSingleOrNull();
  }

  /// Get all unsynced concerts (for cloud sync)
  Future<List<Concert>> getUnsyncedConcerts() {
    return (select(concerts)..where((c) => c.synced.equals(false))).get();
  }

  /// Mark concert as synced
  Future<void> markConcertAsSynced(String id) {
    return (update(concerts)..where((c) => c.id.equals(id)))
        .write(const ConcertsCompanion(synced: Value(true)));
  }

  /// Soft delete concert
  Future<void> softDeleteConcert(String id) {
    return (update(concerts)..where((c) => c.id.equals(id))).write(
      ConcertsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: const Value(false), // Mark for sync
      ),
    );
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return openDatabaseConnection();
}
