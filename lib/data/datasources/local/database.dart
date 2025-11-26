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

/// Table definition for songs
class Songs extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// ID of the concert this song belongs to
  TextColumn get concertId => text()();

  /// Song title
  TextColumn get title => text()();

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

/// Table definition for tracks
class Tracks extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// ID of the song this track belongs to
  TextColumn get songId => text()();

  /// Track name
  TextColumn get name => text()();

  /// Voice part (e.g., Soprano, Alto, Tenor, Bass)
  TextColumn get voicePart => text()();

  /// Local file path to audio file
  TextColumn get filePath => text().nullable()();

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
@DriftDatabase(tables: [Choirs, ChoirMembers, Concerts, Songs, Tracks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

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
          if (from == 2 && to == 3) {
            // Add Songs table
            await m.createTable(songs);

            // Create index for concert_id lookup
            await customStatement(
              'CREATE INDEX idx_songs_concert ON songs(concert_id)',
            );
          }
          if (from == 3 && to == 4) {
            // Add Tracks table
            await m.createTable(tracks);

            // Create index for song_id lookup
            await customStatement(
              'CREATE INDEX idx_tracks_song ON tracks(song_id)',
            );
          }
          // Handle multi-version upgrade (e.g., 1 -> 4)
          if (from == 1 && to == 4) {
            // Add Choirs and ChoirMembers tables
            await m.createTable(choirs);
            await m.createTable(choirMembers);

            // Add Songs table
            await m.createTable(songs);

            // Add Tracks table
            await m.createTable(tracks);

            // Create indexes for performance
            await customStatement(
              'CREATE INDEX idx_choir_members_user ON choir_members(user_id)',
            );
            await customStatement(
              'CREATE INDEX idx_choir_members_choir ON choir_members(choir_id)',
            );
            await customStatement(
              'CREATE INDEX idx_songs_concert ON songs(concert_id)',
            );
            await customStatement(
              'CREATE INDEX idx_tracks_song ON tracks(song_id)',
            );
          }
          // Handle 2 -> 4 upgrade
          if (from == 2 && to == 4) {
            // Add Songs table
            await m.createTable(songs);

            // Add Tracks table
            await m.createTable(tracks);

            // Create indexes
            await customStatement(
              'CREATE INDEX idx_songs_concert ON songs(concert_id)',
            );
            await customStatement(
              'CREATE INDEX idx_tracks_song ON tracks(song_id)',
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

  /// Get all active (non-deleted) songs for a specific concert
  ///
  /// Songs are returned in chronological order (oldest first).
  Future<List<Song>> getSongsByConcert(String concertId) {
    return (select(songs)
          ..where((s) => s.concertId.equals(concertId))
          ..where((s) => s.deleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();
  }

  /// Watch songs for a specific concert (reactive stream)
  Stream<List<Song>> watchSongsByConcert(String concertId) {
    return (select(songs)
          ..where((s) => s.concertId.equals(concertId))
          ..where((s) => s.deleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .watch();
  }

  /// Get song by ID
  Future<Song?> getSongById(String id) {
    return (select(songs)
          ..where((s) => s.id.equals(id))
          ..where((s) => s.deleted.equals(false)))
        .getSingleOrNull();
  }

  /// Get all unsynced songs (for cloud sync)
  Future<List<Song>> getUnsyncedSongs() {
    return (select(songs)..where((s) => s.synced.equals(false))).get();
  }

  /// Mark song as synced
  Future<void> markSongAsSynced(String id) {
    return (update(songs)..where((s) => s.id.equals(id)))
        .write(const SongsCompanion(synced: Value(true)));
  }

  /// Soft delete song
  Future<void> softDeleteSong(String id) {
    return (update(songs)..where((s) => s.id.equals(id))).write(
      SongsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: const Value(false), // Mark for sync
      ),
    );
  }

  /// Get all active (non-deleted) tracks for a specific song
  ///
  /// Tracks are returned in chronological order (oldest first).
  Future<List<Track>> getTracksBySong(String songId) {
    return (select(tracks)
          ..where((t) => t.songId.equals(songId))
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Watch tracks for a specific song (reactive stream)
  Stream<List<Track>> watchTracksBySong(String songId) {
    return (select(tracks)
          ..where((t) => t.songId.equals(songId))
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Get track by ID
  Future<Track?> getTrackById(String id) {
    return (select(tracks)
          ..where((t) => t.id.equals(id))
          ..where((t) => t.deleted.equals(false)))
        .getSingleOrNull();
  }

  /// Get all unsynced tracks (for cloud sync)
  Future<List<Track>> getUnsyncedTracks() {
    return (select(tracks)..where((t) => t.synced.equals(false))).get();
  }

  /// Mark track as synced
  Future<void> markTrackAsSynced(String id) {
    return (update(tracks)..where((t) => t.id.equals(id)))
        .write(const TracksCompanion(synced: Value(true)));
  }

  /// Soft delete track
  Future<void> softDeleteTrack(String id) {
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
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
