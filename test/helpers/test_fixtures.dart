import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

// Shared test data
class TestFixtures {
  static Concert springConcert({String? id}) => Concert(
    id: id ?? 'c1',
    choirId: 'choir1',
    choirName: 'Test Choir',
    name: 'Spring Concert 2025',
    concertDate: DateTime(2025, 4, 15),
    createdAt: DateTime.now(),
  );

  static Song testSong({String? id, String? concertId}) => Song(
    id: id ?? 's1',
    concertId: concertId ?? 'c1',
    title: 'Test Song',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  static Track sopranoTrack({String? id, String? songId}) => Track(
    id: id ?? 't1',
    songId: songId ?? 's1',
    name: 'Soprano',
    filePath: '/test/audio.mp3',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}