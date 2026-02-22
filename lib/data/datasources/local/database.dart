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
          // Step-by-step migration: each case handles exactly one version
          // increment. This ensures multi-version upgrades (e.g. v8 → v12)
          // apply every intermediate step in order, preventing tables or
          // columns from being silently skipped.
          //
          // IMPORTANT: newly-created tables use raw SQL with the historical
          // schema at that version, NOT m.createTable(). Using m.createTable()
          // would create the table with the *current* Dart model (all future
          // columns included), which would cause subsequent ALTER TABLE ADD
          // COLUMN migrations to fail with "column already exists".
          for (var step = from; step < to; step++) {
            switch (step) {
              case 1: // v1 → v2: add Choirs and ChoirMembers
                await m.createTable(choirs);
                // choir_members v2 schema: no updated_at, no deleted
                // (both are added in step 10 / v10→v11)
                await customStatement('''
                  CREATE TABLE choir_members (
                    choir_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    joined_at INTEGER NOT NULL,
                    synced INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (choir_id, user_id)
                  )
                ''');
                await customStatement(
                  'CREATE INDEX idx_choir_members_user ON choir_members(user_id)',
                );
                await customStatement(
                  'CREATE INDEX idx_choir_members_choir ON choir_members(choir_id)',
                );

              case 2: // v2 → v3: add Songs
                await m.createTable(songs);
                await customStatement(
                  'CREATE INDEX idx_songs_concert ON songs(concert_id)',
                );

              case 3: // v3 → v4: add Tracks (with voice_part, removed in step 4)
                await customStatement('''
                  CREATE TABLE tracks (
                    id TEXT NOT NULL PRIMARY KEY,
                    song_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    file_path TEXT,
                    voice_part TEXT,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    synced INTEGER NOT NULL DEFAULT 0
                  )
                ''');
                await customStatement(
                  'CREATE INDEX idx_tracks_song ON tracks(song_id)',
                );

              case 4: // v4 → v5: remove voice_part from tracks
                // SQLite doesn't support DROP COLUMN, so recreate the table.
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
                await customStatement('''
                  INSERT INTO tracks_new
                    (id, song_id, name, file_path, created_at, updated_at, deleted, synced)
                  SELECT id, song_id, name, file_path, created_at, updated_at, deleted, synced
                  FROM tracks
                ''');
                await customStatement('DROP TABLE tracks');
                await customStatement('ALTER TABLE tracks_new RENAME TO tracks');
                await customStatement(
                  'CREATE INDEX idx_tracks_song ON tracks(song_id)',
                );

              case 5: // v5 → v6: add audio columns to tracks
                await customStatement('ALTER TABLE tracks ADD COLUMN audio_url TEXT');
                await customStatement('ALTER TABLE tracks ADD COLUMN storage_path TEXT');
                await customStatement('ALTER TABLE tracks ADD COLUMN duration_ms INTEGER');

              case 6: // v6 → v7: add MarkerSets and Markers
                // marker_sets v7 schema: no is_time_synced (step 7), no markers_json (step 11)
                await customStatement('''
                  CREATE TABLE marker_sets (
                    id TEXT NOT NULL PRIMARY KEY,
                    track_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    is_shared INTEGER NOT NULL DEFAULT 0,
                    created_by_user_id TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    synced INTEGER NOT NULL DEFAULT 0
                  )
                ''');
                // markers v7 schema: no updated_at (added in step 10 / v10→v11)
                await customStatement('''
                  CREATE TABLE markers (
                    id TEXT NOT NULL PRIMARY KEY,
                    marker_set_id TEXT NOT NULL,
                    label TEXT NOT NULL,
                    position_ms INTEGER NOT NULL,
                    display_order INTEGER NOT NULL,
                    created_at INTEGER NOT NULL,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    synced INTEGER NOT NULL DEFAULT 0
                  )
                ''');
                await customStatement(
                  'CREATE INDEX idx_marker_sets_track ON marker_sets(track_id)',
                );
                await customStatement(
                  'CREATE INDEX idx_marker_sets_user ON marker_sets(created_by_user_id)',
                );
                await customStatement(
                  'CREATE INDEX idx_markers_set ON markers(marker_set_id)',
                );

              case 7: // v7 → v8: add is_time_synced to marker_sets
                await customStatement(
                  'ALTER TABLE marker_sets ADD COLUMN is_time_synced INTEGER NOT NULL DEFAULT 1',
                );

              case 8: // v8 → v9: add FavoriteTracks
                // favorite_tracks v9 schema: no deleted (step 9), no updated_at (step 10)
                await customStatement('''
                  CREATE TABLE favorite_tracks (
                    user_id TEXT NOT NULL,
                    track_id TEXT NOT NULL,
                    song_id TEXT NOT NULL,
                    added_at INTEGER NOT NULL,
                    synced INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (user_id, track_id)
                  )
                ''');
                await customStatement(
                  'CREATE INDEX idx_favorite_tracks_user ON favorite_tracks(user_id)',
                );
                await customStatement(
                  'CREATE INDEX idx_favorite_tracks_track ON favorite_tracks(track_id)',
                );
                await customStatement(
                  'CREATE INDEX idx_favorite_tracks_user_added ON favorite_tracks(user_id, added_at DESC)',
                );

              case 9: // v9 → v10: add deleted to favorite_tracks (soft-delete sync)
                await customStatement(
                  'ALTER TABLE favorite_tracks ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
                );

              case 10: // v10 → v11: add updated_at to multiple tables
                await customStatement(
                  'ALTER TABLE markers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
                );
                await customStatement('UPDATE markers SET updated_at = created_at');

                await customStatement(
                  'ALTER TABLE choir_members ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
                );
                await customStatement('UPDATE choir_members SET updated_at = joined_at');
                await customStatement(
                  'ALTER TABLE choir_members ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
                );

                await customStatement(
                  'ALTER TABLE favorite_tracks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
                );
                await customStatement('UPDATE favorite_tracks SET updated_at = added_at');

                await customStatement('DROP TABLE IF EXISTS user_playback_states');

              case 11: // v11 → v12: add markers_json to marker_sets + backfill
                await customStatement(
                  "ALTER TABLE marker_sets ADD COLUMN markers_json TEXT NOT NULL DEFAULT '[]'",
                );

                // Backfill JSON payload from legacy marker rows.
                // At this point all columns referenced below exist:
                //   marker_sets.markers_json  (just added above)
                //   markers.updated_at        (added in step 10)
                final allMarkerSets = await (select(markerSets)).get();
                for (final markerSet in allMarkerSets) {
                  final rows = await (select(markers)
                        ..where((t) => t.markerSetId.equals(markerSet.id))
                        ..where((t) => t.deleted.equals(false))
                        ..orderBy([(t) => OrderingTerm.asc(t.displayOrder)]))
                      .get();
                  final payload = rows
                      .map(
                        (marker) => <String, dynamic>{
                          'label': marker.label,
                          'position_ms': marker.positionMs,
                        },
                      )
                      .toList(growable: false);
                  final jsonStr = jsonEncode(payload);
                  await (update(markerSets)
                        ..where((ms) => ms.id.equals(markerSet.id)))
                      .write(MarkerSetsCompanion(markersJson: Value(jsonStr)));
                }
            }
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

  /// Get favorite tracks with song and concert metadata in a single query.
  ///
  /// Replaces the N+1 pattern in [_getFavoriteMediaItems]: instead of
  /// fetching song and concert separately for each favourite, this joins all
  /// four tables at once. Used by Android Auto content browsing.
  Future<
      List<
          ({
            FavoriteTrack favorite,
            Track track,
            Song? song,
            Concert? concert,
          })>> getFavoriteTracksWithMeta(String userId) async {
    final query = select(favoriteTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(favoriteTracks.trackId)),
      leftOuterJoin(songs, songs.id.equalsExp(tracks.songId)),
      leftOuterJoin(concerts, concerts.id.equalsExp(songs.concertId)),
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
        song: row.readTableOrNull(songs),
        concert: row.readTableOrNull(concerts),
      );
    }).toList();
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return openDatabaseConnection();
}
