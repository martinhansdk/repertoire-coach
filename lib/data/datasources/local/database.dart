import 'dart:convert';

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

  /// When this record was last updated (for sync)
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete flag (true = deleted, false = active)
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

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

  /// Public URL to access the audio file (from Supabase Storage)
  TextColumn get audioUrl => text().nullable()();

  /// Path in Supabase Storage bucket
  TextColumn get storagePath => text().nullable()();

  /// Duration of the audio file in milliseconds
  IntColumn get durationMs => integer().nullable()();

  /// Local file path to audio file (legacy, for offline/temp use)
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

/// Table definition for marker sets (collections of markers for tracks)
class MarkerSets extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// ID of the track this marker set belongs to
  TextColumn get trackId => text()();

  /// Name of the marker set (e.g., "Musical Structure", "Bar Numbers")
  TextColumn get name => text()();

  /// Is this marker set shared with choir members?
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  /// Are markers synced to audio positions?
  BoolColumn get isTimeSynced => boolean().withDefault(const Constant(true))();

  /// ID of the user who created this marker set
  TextColumn get createdByUserId => text()();

  /// When this record was created
  DateTimeColumn get createdAt => dateTime()();

  /// When this record was last updated (for sync)
  DateTimeColumn get updatedAt => dateTime()();

  /// JSON payload of markers in canonical display order.
  /// Each entry is {"label": String, "position_ms": int|null}.
  TextColumn get markersJson => text().withDefault(const Constant('[]'))();

  /// Soft delete flag (true = deleted, false = active)
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table definition for markers (individual position markers within marker sets)
class Markers extends Table {
  /// Unique identifier (UUID)
  TextColumn get id => text()();

  /// ID of the marker set this marker belongs to
  TextColumn get markerSetId => text()();

  /// Label for this marker (e.g., "intro", "verse 1", "bar 25")
  TextColumn get label => text()();

  /// Position in track in milliseconds
  IntColumn get positionMs => integer()();

  /// Display order within the marker set
  IntColumn get displayOrder => integer()();

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

/// Table definition for favorite tracks (per-user, synced across devices)
class FavoriteTracks extends Table {
  /// ID of the user who favorited this track
  TextColumn get userId => text()();

  /// ID of the favorited track
  TextColumn get trackId => text()();

  /// ID of the song containing this track (for efficient queries)
  TextColumn get songId => text()();

  /// When this track was added to favorites
  DateTimeColumn get addedAt => dateTime()();

  /// When this record was last updated (for sync)
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete flag (true = deleted, false = active)
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId, trackId};
}

/// Main application database
@DriftDatabase(tables: [
  Choirs,
  ChoirMembers,
  Concerts,
  Songs,
  Tracks,
  MarkerSets,
  Markers,
  FavoriteTracks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 12;

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
          if (from == 4 && to == 5) {
            // Remove voice_part column from tracks table
            // SQLite doesn't support DROP COLUMN directly in older versions,
            // so we need to recreate the table
            await customStatement('''
              CREATE TABLE tracks_new (
                id TEXT NOT NULL PRIMARY KEY,
                song_id TEXT NOT NULL,
                name TEXT NOT NULL,
                file_path TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');

            // Copy data from old table to new (excluding voice_part)
            await customStatement('''
              INSERT INTO tracks_new (id, song_id, name, file_path, created_at, updated_at, deleted, synced)
              SELECT id, song_id, name, file_path, created_at, updated_at, deleted, synced
              FROM tracks
            ''');

            // Drop old table
            await customStatement('DROP TABLE tracks');

            // Rename new table to original name
            await customStatement('ALTER TABLE tracks_new RENAME TO tracks');

            // Recreate index
            await customStatement(
              'CREATE INDEX idx_tracks_song ON tracks(song_id)',
            );
          }
          if (from == 6 && to == 7) {
            // Add MarkerSets and Markers tables
            await m.createTable(markerSets);
            await m.createTable(markers);

            // Create indexes for performance
            await customStatement(
              'CREATE INDEX idx_marker_sets_track ON marker_sets(track_id)',
            );
            await customStatement(
              'CREATE INDEX idx_marker_sets_user ON marker_sets(created_by_user_id)',
            );
            await customStatement(
              'CREATE INDEX idx_markers_set ON markers(marker_set_id)',
            );
          }
          if (from == 7 && to == 8) {
            // Add is_time_synced to marker_sets
            await customStatement(
              'ALTER TABLE marker_sets ADD COLUMN is_time_synced INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (from == 9 && to == 10) {
            // Add deleted column to FavoriteTracks for soft-delete sync
            await customStatement(
              'ALTER TABLE favorite_tracks ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (from == 10 && to == 11) {
            // Add updated_at to markers
            await customStatement(
              'ALTER TABLE markers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'UPDATE markers SET updated_at = created_at',
            );

            // Add updated_at and deleted to choir_members
            await customStatement(
              'ALTER TABLE choir_members ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'UPDATE choir_members SET updated_at = joined_at',
            );
            await customStatement(
              'ALTER TABLE choir_members ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
            );

            // Add updated_at to favorite_tracks
            await customStatement(
              'ALTER TABLE favorite_tracks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'UPDATE favorite_tracks SET updated_at = added_at',
            );

            // Drop user_playback_states table
            await customStatement(
              'DROP TABLE IF EXISTS user_playback_states',
            );
          }
          if (from < 12 && to >= 12) {
            await customStatement(
              "ALTER TABLE marker_sets ADD COLUMN markers_json TEXT NOT NULL DEFAULT '[]'",
            );

            // Backfill payload from legacy marker rows ordered by display_order.
            final allMarkerSets = await (select(markerSets)).get();
            for (final markerSet in allMarkerSets) {
              final rows = await (select(markers)
                    ..where((m) => m.markerSetId.equals(markerSet.id))
                    ..where((m) => m.deleted.equals(false))
                    ..orderBy([(m) => OrderingTerm.asc(m.displayOrder)]))
                  .get();
              final payload = rows
                  .map(
                    (marker) => <String, dynamic>{
                      'label': marker.label,
                      'position_ms': marker.positionMs,
                    },
                  )
                  .toList(growable: false);
              final json = jsonEncode(payload);
              await (update(markerSets)..where((ms) => ms.id.equals(markerSet.id)))
                  .write(
                MarkerSetsCompanion(markersJson: Value(json)),
              );
            }
          }
          if (from == 8 && to == 9) {
            // Add FavoriteTracks table
            await m.createTable(favoriteTracks);

            // Create indexes for performance
            await customStatement(
              'CREATE INDEX idx_favorite_tracks_user ON favorite_tracks(user_id)',
            );
            await customStatement(
              'CREATE INDEX idx_favorite_tracks_track ON favorite_tracks(track_id)',
            );
            await customStatement(
              'CREATE INDEX idx_favorite_tracks_user_added ON favorite_tracks(user_id, added_at DESC)',
            );
          }
          // Handle multi-version upgrade (e.g., 1 -> 5)
          if (from == 1 && to == 5) {
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
          // Handle 2 -> 5 upgrade
          if (from == 2 && to == 5) {
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
          // Handle 3 -> 5 upgrade
          if (from == 3 && to == 5) {
            // Add Tracks table
            await m.createTable(tracks);

            // Create index
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

  /// Hard delete tracks that are not in the given set of IDs
  ///
  /// Used during sync to remove tracks that were deleted on remote.
  /// Only deletes tracks that are already synced (came from remote).
  Future<void> hardDeleteTracksNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(tracks)
          ..where((t) => t.id.isNotIn(keepIds))
          ..where((t) => t.synced.equals(true)))
        .go();
  }

  /// Hard delete concerts that are not in the given set of IDs
  ///
  /// Used during sync to remove concerts deleted on remote.
  /// Only deletes concerts that are already synced.
  Future<void> hardDeleteConcertsNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(concerts)
          ..where((c) => c.id.isNotIn(keepIds))
          ..where((c) => c.synced.equals(true)))
        .go();
  }

  /// Hard delete songs that are not in the given set of IDs
  ///
  /// Used during sync to remove songs deleted on remote.
  /// Only deletes songs that are already synced.
  Future<void> hardDeleteSongsNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(songs)
          ..where((s) => s.id.isNotIn(keepIds))
          ..where((s) => s.synced.equals(true)))
        .go();
  }

  /// Hard delete marker sets that are not in the given set of IDs
  ///
  /// Used during sync to remove marker sets deleted on remote.
  /// Only deletes marker sets that are already synced.
  Future<void> hardDeleteMarkerSetsNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(markerSets)
          ..where((ms) => ms.id.isNotIn(keepIds))
          ..where((ms) => ms.synced.equals(true)))
        .go();
  }

  /// Hard delete markers that are not in the given set of IDs
  ///
  /// Used during sync to remove markers deleted on remote.
  /// Only deletes markers that are already synced.
  Future<void> hardDeleteMarkersNotIn(Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(markers)
          ..where((m) => m.id.isNotIn(keepIds))
          ..where((m) => m.synced.equals(true)))
        .go();
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

  /// Get favorite tracks for a user, joined with track data.
  ///
  /// Returns a list of records containing both the favorite metadata and the
  /// full Track row. Used by Android Auto content browsing.
  Future<List<({FavoriteTrack favorite, Track track})>> getFavoriteTracks(
    String userId,
  ) async {
    final query = select(favoriteTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(favoriteTracks.trackId)),
    ])
      ..where(favoriteTracks.userId.equals(userId))
      ..where(favoriteTracks.deleted.equals(false))
      ..where(tracks.deleted.equals(false))
      ..orderBy([OrderingTerm.desc(favoriteTracks.addedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return (
        favorite: row.readTable(favoriteTracks),
        track: row.readTable(tracks),
      );
    }).toList();
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return openDatabaseConnection();
}
