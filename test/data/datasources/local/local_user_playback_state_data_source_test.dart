import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_user_playback_state_data_source.dart';
import 'package:repertoire_coach/data/models/user_playback_state_model.dart';

import '../../../helpers/test_database_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalUserPlaybackStateDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalUserPlaybackStateDataSource(database);
    await dataSource.clearAll();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  final testState = UserPlaybackStateModel(
    id: 'u1_t1',
    userId: 'u1',
    songId: 's1',
    trackId: 't1',
    position: 12345,
    updatedAt: DateTime.now(),
  );

  test('savePlaybackState and getPlaybackState', () async {
    await dataSource.savePlaybackState(testState);
    final result = await dataSource.getPlaybackState('u1', 't1');
    expect(result, isA<UserPlaybackStateModel>());
    expect(result?.position, 12345);
  });

  test('getPlaybackState returns null for non-existent state', () async {
    final result = await dataSource.getPlaybackState('u1', 'non-existent');
    expect(result, isNull);
  });

  test('savePlaybackState updates an existing state', () async {
    await dataSource.savePlaybackState(testState);
    final updatedState = UserPlaybackStateModel(
      id: 'u1_t1',
      userId: 'u1',
      songId: 's1',
      trackId: 't1',
      position: 54321,
      updatedAt: DateTime.now(),
    );
    await dataSource.savePlaybackState(updatedState);
    final result = await dataSource.getPlaybackState('u1', 't1');
    expect(result?.position, 54321);
  });

  test('deletePlaybackState removes a state', () async {
    await dataSource.savePlaybackState(testState);
    await dataSource.deletePlaybackState('u1', 't1');
    final result = await dataSource.getPlaybackState('u1', 't1');
    expect(result, isNull);
  });

  test('clearAllForUser removes all states for that user', () async {
    final otherUserState = UserPlaybackStateModel(
      id: 'u2_t1',
      userId: 'u2',
      songId: 's1',
      trackId: 't1',
      position: 123,
      updatedAt: DateTime.now(),
    );
    await dataSource.savePlaybackState(testState);
    await dataSource.savePlaybackState(otherUserState);

    await dataSource.clearAllForUser('u1');

    final result1 = await dataSource.getPlaybackState('u1', 't1');
    final result2 = await dataSource.getPlaybackState('u2', 't1');
    expect(result1, isNull);
    expect(result2, isNotNull);
  });

  test('clearAll removes all states', () async {
    await dataSource.savePlaybackState(testState);
    await dataSource.clearAll();
    final result = await dataSource.getPlaybackState('u1', 't1');
    expect(result, isNull);
  });
}
