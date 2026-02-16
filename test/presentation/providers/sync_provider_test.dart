import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/core/services/sync_service.dart';
import 'package:repertoire_coach/data/datasources/local/local_choir_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_user_playback_state_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_choir_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_concert_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_marker_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_song_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_user_playback_state_data_source.dart';
import 'package:repertoire_coach/presentation/providers/auth_provider.dart';
import 'package:repertoire_coach/presentation/providers/marker_provider.dart';
import 'package:repertoire_coach/presentation/providers/sync_provider.dart';

class _DummyLocalChoirDataSource extends Fake
    implements LocalChoirDataSource {}
class _DummyLocalConcertDataSource extends Fake
    implements LocalConcertDataSource {}
class _DummyLocalSongDataSource extends Fake implements LocalSongDataSource {}
class _DummyLocalTrackDataSource extends Fake implements LocalTrackDataSource {}
class _DummyLocalMarkerDataSource extends Fake implements LocalMarkerDataSource {}
class _DummyLocalPlaybackStateDataSource extends Fake
    implements LocalUserPlaybackStateDataSource {}
class _DummyRemoteChoirDataSource extends Fake
    implements RemoteChoirDataSource {}
class _DummyRemoteConcertDataSource extends Fake
    implements RemoteConcertDataSource {}
class _DummyRemoteSongDataSource extends Fake implements RemoteSongDataSource {}
class _DummyRemoteTrackDataSource extends Fake implements RemoteTrackDataSource {}
class _DummyRemoteMarkerDataSource extends Fake
    implements RemoteMarkerDataSource {}
class _DummyRemotePlaybackStateDataSource extends Fake
    implements RemoteUserPlaybackStateDataSource {}
class _DummyLocalFavoriteTrackDataSource extends Fake
    implements LocalFavoriteTrackDataSource {}
class _DummyRemoteFavoriteTrackDataSource extends Fake
    implements RemoteFavoriteTrackDataSource {}

class _FakeSyncService extends SyncService {
  _FakeSyncService()
      : super(
          localChoirDataSource: _DummyLocalChoirDataSource(),
          localConcertDataSource: _DummyLocalConcertDataSource(),
          localSongDataSource: _DummyLocalSongDataSource(),
          localTrackDataSource: _DummyLocalTrackDataSource(),
          localMarkerDataSource: _DummyLocalMarkerDataSource(),
          localPlaybackStateDataSource: _DummyLocalPlaybackStateDataSource(),
          localFavoriteTrackDataSource: _DummyLocalFavoriteTrackDataSource(),
          remoteChoirDataSource: _DummyRemoteChoirDataSource(),
          remoteConcertDataSource: _DummyRemoteConcertDataSource(),
          remoteSongDataSource: _DummyRemoteSongDataSource(),
          remoteTrackDataSource: _DummyRemoteTrackDataSource(),
          remoteMarkerDataSource: _DummyRemoteMarkerDataSource(),
          remotePlaybackStateDataSource: _DummyRemotePlaybackStateDataSource(),
          remoteFavoriteTrackDataSource: _DummyRemoteFavoriteTrackDataSource(),
        );

  @override
  Future<void> syncFromRemote(
    String userId, {
    void Function(SyncState state)? onProgress,
  }) async {
    onProgress?.call(SyncState.syncing(currentEntity: 'markers', progress: 0.5));
    onProgress?.call(SyncState.success(message: 'done'));
  }
}

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'user-1';

  @override
  bool get isAuthenticated => true;
}

void main() {
  test('sync invalidates marker providers', () async {
    var markerSetsReads = 0;
    var markersReads = 0;

    final container = ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
        syncServiceProvider.overrideWithValue(_FakeSyncService()),
        markerSetsByTrackProvider(('track-1', 'user-1')).overrideWith(
          (ref) async {
            markerSetsReads += 1;
            return [];
          },
        ),
        markersByMarkerSetProvider('set-1').overrideWith(
          (ref) async {
            markersReads += 1;
            return [];
          },
        ),
        markerSetByIdProvider('set-1').overrideWith((ref) async => null),
      ],
    );

    await container.read(markerSetsByTrackProvider(('track-1', 'user-1')).future);
    await container.read(markersByMarkerSetProvider('set-1').future);
    expect(markerSetsReads, 1);
    expect(markersReads, 1);

    await container.read(syncControllerProvider.notifier).syncFromRemote();

    await container.read(markerSetsByTrackProvider(('track-1', 'user-1')).future);
    await container.read(markersByMarkerSetProvider('set-1').future);
    expect(markerSetsReads, 2);
    expect(markersReads, 2);
  });
}
