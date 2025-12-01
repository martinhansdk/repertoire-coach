import 'package:repertoire_coach/domain/entities/concert.dart';
import 'package:repertoire_coach/domain/entities/song.dart';
import 'package:repertoire_coach/domain/entities/track.dart';

// Shared test data
class TestFixtures {
  static Concert springConcert({String? id}) => Concert(
    id: id ?? 'c1',
    name: 'Spring Concert 2025',
    date: DateTime(2025, 4, 15),
  );

  static Song testSong({String? id, String? concertId}) => Song(
    id: id ?? 's1',
    title: 'Test Song',
    concertId: concertId ?? 'c1',
  );

  static Track sopranoTrack({String? id, String? songId}) => Track(
    id: id ?? 't1',
    name: 'Soprano',
    songId: songId ?? 's1',
    audioFile: '/test/audio.mp3',
  );
}
