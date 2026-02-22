import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite3;

/// Builds an in-memory SQLite database that looks exactly like the v8 schema
/// (before favorite_tracks was introduced at v9).
///
/// Used to simulate a device that hasn't opened the app in a long time and is
/// now upgrading several schema versions at once (v8 → 12).
raw_sqlite3.Database _buildV8Database() {
  final db = raw_sqlite3.sqlite3.openInMemory();

  db.execute('''
    CREATE TABLE choirs (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // choir_members at v8: no updated_at, no deleted (both added in v10→v11)
  db.execute('''
    CREATE TABLE choir_members (
      choir_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      joined_at INTEGER NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (choir_id, user_id)
    )
  ''');

  db.execute('''
    CREATE TABLE concerts (
      id TEXT NOT NULL PRIMARY KEY,
      choir_id TEXT NOT NULL,
      choir_name TEXT NOT NULL,
      name TEXT NOT NULL,
      concert_date INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');

  db.execute('''
    CREATE TABLE songs (
      id TEXT NOT NULL PRIMARY KEY,
      concert_id TEXT NOT NULL,
      title TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');

  db.execute('''
    CREATE TABLE tracks (
      id TEXT NOT NULL PRIMARY KEY,
      song_id TEXT NOT NULL,
      name TEXT NOT NULL,
      audio_url TEXT,
      storage_path TEXT,
      duration_ms INTEGER,
      file_path TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // marker_sets at v8: has is_time_synced (added v7→v8), but NO markers_json (v11→v12)
  db.execute('''
    CREATE TABLE marker_sets (
      id TEXT NOT NULL PRIMARY KEY,
      track_id TEXT NOT NULL,
      name TEXT NOT NULL,
      is_shared INTEGER NOT NULL DEFAULT 0,
      is_time_synced INTEGER NOT NULL DEFAULT 1,
      created_by_user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // markers at v8: no updated_at (added in v10→v11)
  db.execute('''
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

  // Indexes that existed at v8
  db.execute('CREATE INDEX idx_choir_members_user ON choir_members(user_id)');
  db.execute('CREATE INDEX idx_choir_members_choir ON choir_members(choir_id)');
  db.execute('CREATE INDEX idx_songs_concert ON songs(concert_id)');
  db.execute('CREATE INDEX idx_tracks_song ON tracks(song_id)');
  db.execute('CREATE INDEX idx_marker_sets_track ON marker_sets(track_id)');
  db.execute('CREATE INDEX idx_marker_sets_user ON marker_sets(created_by_user_id)');
  db.execute('CREATE INDEX idx_markers_set ON markers(marker_set_id)');

  // Set schema version to 8
  db.execute('PRAGMA user_version = 8');

  return db;
}

/// Builds an in-memory SQLite database that looks like v11 (one version behind
/// the current v12). Used to verify the normal single-step upgrade path.
raw_sqlite3.Database _buildV11Database() {
  final db = _buildV8Database();

  // Apply v9: create favorite_tracks (historical schema)
  db.execute('''
    CREATE TABLE favorite_tracks (
      user_id TEXT NOT NULL,
      track_id TEXT NOT NULL,
      song_id TEXT NOT NULL,
      added_at INTEGER NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, track_id)
    )
  ''');
  db.execute('CREATE INDEX idx_favorite_tracks_user ON favorite_tracks(user_id)');
  db.execute('CREATE INDEX idx_favorite_tracks_track ON favorite_tracks(track_id)');
  db.execute('CREATE INDEX idx_favorite_tracks_user_added ON favorite_tracks(user_id, added_at DESC)');

  // Apply v10: add deleted to favorite_tracks
  db.execute('ALTER TABLE favorite_tracks ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');

  // Apply v11: add updated_at to markers and choir_members; drop user_playback_states
  db.execute('ALTER TABLE markers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
  db.execute('ALTER TABLE choir_members ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
  db.execute('ALTER TABLE choir_members ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
  db.execute('ALTER TABLE favorite_tracks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');

  db.execute('PRAGMA user_version = 11');

  return db;
}

void main() {
  group('AppDatabase migration', () {
    test('v8 → 12: favorite_tracks table is created', () async {
      // Arrange — open a v8 database (no favorite_tracks table)
      final rawDb = _buildV8Database();
      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));

      // Act — Drift detects user_version=8 and runs onUpgrade(m, 8, 12)
      // getFavoriteTracks exercises the favorite_tracks table
      final favorites = await db.getFavoriteTracks('test-user');

      // Assert — table exists and returns empty list
      expect(favorites, isEmpty);

      await db.close();
    });

    test('v8 → 12: choir_members gains updated_at and deleted columns', () async {
      final rawDb = _buildV8Database();

      // Insert a choir_member row using only the v8 columns
      rawDb.execute('''
        INSERT INTO choir_members (choir_id, user_id, joined_at, synced)
        VALUES ('c1', 'u1', 1000, 0)
      ''');

      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));

      // Trigger migration by performing a query
      await db.getFavoriteTracks('u1');

      // Verify updated_at (backfilled from joined_at=1000) and deleted (DEFAULT 0)
      final rows = rawDb.select('SELECT updated_at, deleted FROM choir_members');
      expect(rows, hasLength(1));
      expect(rows.first['updated_at'], 1000); // backfilled from joined_at
      expect(rows.first['deleted'], 0); // DEFAULT 0

      await db.close();
    });

    test('v8 → 12: markers gains updated_at column', () async {
      final rawDb = _buildV8Database();

      rawDb.execute('''
        INSERT INTO marker_sets (id, track_id, name, is_shared, is_time_synced,
          created_by_user_id, created_at, updated_at, deleted, synced)
        VALUES ('ms1', 't1', 'Test Set', 0, 1, 'u1', 1000, 1000, 0, 0)
      ''');
      rawDb.execute('''
        INSERT INTO markers (id, marker_set_id, label, position_ms, display_order,
          created_at, deleted, synced)
        VALUES ('m1', 'ms1', 'Intro', 0, 0, 1000, 0, 0)
      ''');

      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));
      await db.getFavoriteTracks('u1');

      final rows = rawDb.select('SELECT updated_at FROM markers');
      expect(rows, hasLength(1));
      expect(rows.first['updated_at'], 1000); // backfilled from created_at

      await db.close();
    });

    test('v8 → 12: marker_sets gains markers_json column with backfill', () async {
      final rawDb = _buildV8Database();

      rawDb.execute('''
        INSERT INTO marker_sets (id, track_id, name, is_shared, is_time_synced,
          created_by_user_id, created_at, updated_at, deleted, synced)
        VALUES ('ms1', 't1', 'Test Set', 0, 1, 'u1', 1000, 1000, 0, 0)
      ''');
      rawDb.execute('''
        INSERT INTO markers (id, marker_set_id, label, position_ms, display_order,
          created_at, deleted, synced)
        VALUES ('m1', 'ms1', 'Verse 1', 5000, 0, 1000, 0, 0)
      ''');

      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));
      await db.getFavoriteTracks('u1');

      final rows = rawDb.select('SELECT markers_json FROM marker_sets WHERE id = ?', ['ms1']);
      expect(rows, hasLength(1));
      final markersJson = rows.first['markers_json'] as String;
      expect(markersJson, contains('Verse 1'));
      expect(markersJson, contains('5000'));

      await db.close();
    });

    test('v11 → 12: normal single-step upgrade adds markers_json', () async {
      final rawDb = _buildV11Database();
      final db = AppDatabase.forTesting(NativeDatabase.opened(rawDb));

      // Just verify it doesn't throw and favorite_tracks still works
      final favorites = await db.getFavoriteTracks('test-user');
      expect(favorites, isEmpty);

      // Verify markers_json column was added
      final rows = rawDb.select("SELECT markers_json FROM marker_sets LIMIT 1");
      // Table exists with the new column (even if empty)
      expect(rows, isEmpty); // no rows were inserted

      await db.close();
    });
  });
}
