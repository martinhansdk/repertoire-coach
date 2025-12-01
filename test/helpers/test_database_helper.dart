import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' hide Concert, Song, Track;
import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

class TestDatabaseHelper {
  static AppDatabase createTestDatabase() {
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  static Future<void> closeTestDatabase(AppDatabase db) async {
    await db.close();
  }

  static Future<void> seedConcerts(AppDatabase db, List<Concert> concerts) async {
    for (final concert in concerts) {
      await db.into(db.concerts).insert(
            ConcertsCompanion.insert(
              id: concert.id,
              choirId: concert.choirId,
              choirName: concert.choirName,
              name: concert.name,
              concertDate: concert.concertDate,
              createdAt: concert.createdAt,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    }
  }

  static Future<void> seedSongs(AppDatabase db, List<Song> songs) async {
    for (final song in songs) {
      await db.into(db.songs).insert(
            SongsCompanion.insert(
              id: song.id,
              concertId: song.concertId,
              title: song.title,
              createdAt: song.createdAt,
              updatedAt: song.updatedAt,
            ),
          );
    }
  }

  static Future<void> seedTracks(AppDatabase db, List<Track> tracks) async {
    for (final track in tracks) {
      await db.into(db.tracks).insert(
            TracksCompanion.insert(
              id: track.id,
              songId: track.songId,
              name: track.name,
              filePath: Value(track.filePath),
              createdAt: track.createdAt,
              updatedAt: track.updatedAt,
            ),
          );
    }
  }
}