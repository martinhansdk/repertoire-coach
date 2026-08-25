import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/models/favorite_track_model.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalFavoriteTrackDataSource dataSource;

  const userId = 'u1';
  final now = DateTime(2024, 1, 1).toUtc();

  final testTrack = Track(
    id: 't1',
    songId: 's1',
    name: 'Soprano',
    filePath: '/audio/soprano.mp3',
    createdAt: now,
    updatedAt: now,
  );

  final testFavorite = FavoriteTrackModel(
    addedAt: now,
    updatedAt: now,
    track: testTrack,
  );

  /// Inserts a minimal track row so JOIN queries can resolve it.
  Future<void> seedTrack(Track track) async {
    await database.into(database.tracks).insert(
          db.TracksCompanion.insert(
            id: track.id,
            songId: track.songId,
            name: track.name,
            filePath: Value(track.filePath),
            createdAt: track.createdAt,
            updatedAt: track.updatedAt,
          ),
        );
  }

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalFavoriteTrackDataSource(database);
    await dataSource.clearAllForUser(userId);
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  // -----------------------------------------------------------------------
  // Basic CRUD
  // -----------------------------------------------------------------------

  group('addFavorite and getFavorites', () {
    test('addFavorite makes track retrievable via getFavorites', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);

      final favorites = await dataSource.getFavorites(userId);
      expect(favorites.length, 1);
      expect(favorites.first.track.id, 't1');
    });

    test('getFavorites returns empty list when no favorites exist', () async {
      final favorites = await dataSource.getFavorites(userId);
      expect(favorites, isEmpty);
    });

    test('addFavorite is idempotent', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);
      await dataSource.addFavorite(userId, testFavorite);

      final favorites = await dataSource.getFavorites(userId);
      expect(favorites.length, 1);
    });

    test('getFavorites isolates by userId', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);

      final otherFavorites = await dataSource.getFavorites('other-user');
      expect(otherFavorites, isEmpty);
    });
  });

  group('isFavorite', () {
    test('returns true after adding a favorite', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);

      expect(await dataSource.isFavorite(userId, 't1'), isTrue);
    });

    test('returns false for a track that was never favorited', () async {
      expect(await dataSource.isFavorite(userId, 't1'), isFalse);
    });

    test('returns false after the favorite is removed', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);
      await dataSource.removeFavorite(userId, 't1');

      expect(await dataSource.isFavorite(userId, 't1'), isFalse);
    });
  });

  group('removeFavorite', () {
    test('soft-deletes the row', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);
      await dataSource.removeFavorite(userId, 't1');

      // Logical query excludes it
      final favorites = await dataSource.getFavorites(userId);
      expect(favorites, isEmpty);

      // Raw row still exists with deleted=true
      final raw = await (database.select(database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals('t1')))
          .getSingle();
      expect(raw.deleted, isTrue);
    });
  });

  group('getFavoriteCount', () {
    test('returns 0 when no favorites', () async {
      expect(await dataSource.getFavoriteCount(userId), 0);
    });

    test('increments when a favorite is added', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);

      expect(await dataSource.getFavoriteCount(userId), 1);
    });

    test('decrements after favorite is removed', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);
      await dataSource.removeFavorite(userId, 't1');

      expect(await dataSource.getFavoriteCount(userId), 0);
    });
  });

  // -----------------------------------------------------------------------
  // Sync operations
  // -----------------------------------------------------------------------

  group('sync operations', () {
    test('getUnsyncedFavorites returns favorites with synced=false', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite, markForSync: true);

      final unsynced = await dataSource.getUnsyncedFavorites(userId);
      expect(unsynced.length, 1);
      expect(unsynced.first.track.id, 't1');
    });

    test('getUnsyncedFavorites returns empty after markAsSynced', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite, markForSync: true);
      await dataSource.markAsSynced(['t1'], userId, testFavorite.updatedAt);

      final unsynced = await dataSource.getUnsyncedFavorites(userId);
      expect(unsynced, isEmpty);
    });

    test('getUnsyncedFavoriteRecords includes both adds and soft-deletes', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite, markForSync: true);
      await dataSource.removeFavorite(userId, 't1'); // marks synced=false again

      final records = await dataSource.getUnsyncedFavoriteRecords(userId);
      expect(records.length, 1);
    });

    test('upsertFavoriteRecord inserts from remote data without triggering sync', () async {
      await seedTrack(testTrack);
      await dataSource.upsertFavoriteRecord(
        userId: userId,
        trackId: 't1',
        songId: 's1',
        addedAt: now,
        markForSync: false,
      );

      final unsynced = await dataSource.getUnsyncedFavoriteRecords(userId);
      expect(unsynced, isEmpty); // markForSync=false → synced=true

      expect(await dataSource.isFavorite(userId, 't1'), isTrue);
    });

    test('hardDeleteSyncedDeleted removes synced+deleted rows', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite);
      await dataSource.removeFavorite(userId, 't1');
      // The soft-delete stamped a fresh deletion time; conditional markSynced
      // needs the row's current updatedAt.
      final deletedRow = await (database.select(database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals('t1')))
          .getSingle();
      await dataSource.markAsSynced(['t1'], userId, deletedRow.updatedAt);

      await dataSource.hardDeleteSyncedDeleted(userId);

      final raw = await (database.select(database.favoriteTracks)
            ..where((f) => f.userId.equals(userId))
            ..where((f) => f.trackId.equals('t1')))
          .getSingleOrNull();
      expect(raw, isNull);
    });

    test('getSyncedFavorites returns map of synced favorites', () async {
      await seedTrack(testTrack);
      await dataSource.addFavorite(userId, testFavorite, markForSync: false);
      // markForSync=false means it goes in as synced=true

      final synced = await dataSource.getSyncedFavorites(userId);
      expect(synced.containsKey('t1'), isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // Watch stream
  // -----------------------------------------------------------------------

  group('watchFavorites', () {
    test('emits updated list when a favorite is added', () async {
      await seedTrack(testTrack);
      final stream = dataSource.watchFavorites(userId);

      expect(
        stream,
        emitsInOrder([
          emits([]),
          emits(isA<List<FavoriteTrackModel>>()
              .having((l) => l.length, 'length', 1)),
        ]),
      );

      await dataSource.addFavorite(userId, testFavorite);
    });
  });
}
