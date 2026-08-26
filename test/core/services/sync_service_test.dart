import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/core/services/sync_service.dart';
import 'package:repertoire_coach/data/datasources/local/local_choir_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_concert_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_song_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_choir_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_concert_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_marker_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_song_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/local/local_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_favorite_track_data_source.dart';
import 'package:repertoire_coach/data/models/choir_member_model.dart';
import 'package:repertoire_coach/data/models/choir_model.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/data/models/favorite_track_model.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';
import 'package:repertoire_coach/data/models/song_model.dart';
import 'package:repertoire_coach/data/models/track_model.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([
  LocalChoirDataSource,
  LocalConcertDataSource,
  LocalSongDataSource,
  LocalTrackDataSource,
  LocalMarkerDataSource,
  LocalFavoriteTrackDataSource,
  RemoteChoirDataSource,
  RemoteConcertDataSource,
  RemoteSongDataSource,
  RemoteTrackDataSource,
  RemoteMarkerDataSource,
  RemoteFavoriteTrackDataSource,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService', () {
    late SyncService syncService;
    late MockLocalChoirDataSource mockLocalChoirDataSource;
    late MockLocalConcertDataSource mockLocalConcertDataSource;
    late MockLocalSongDataSource mockLocalSongDataSource;
    late MockLocalTrackDataSource mockLocalTrackDataSource;
    late MockLocalMarkerDataSource mockLocalMarkerDataSource;
    late MockRemoteChoirDataSource mockRemoteChoirDataSource;
    late MockRemoteConcertDataSource mockRemoteConcertDataSource;
    late MockRemoteSongDataSource mockRemoteSongDataSource;
    late MockRemoteTrackDataSource mockRemoteTrackDataSource;
    late MockRemoteMarkerDataSource mockRemoteMarkerDataSource;
    late MockLocalFavoriteTrackDataSource mockLocalFavoriteTrackDataSource;
    late MockRemoteFavoriteTrackDataSource mockRemoteFavoriteTrackDataSource;

    const testUserId = 'user-123';

    /// Stubs all data sources to return empty data for a clean sync.
    /// Tests override specific stubs as needed.
    void stubEmptySync() {
      // Remote fetches
      when(mockRemoteChoirDataSource.getChoirs(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteConcertDataSource.getConcerts(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteSongDataSource.getSongsForUser(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
          .thenAnswer((_) async => []);
      when(mockRemoteFavoriteTrackDataSource.getFavorites(testUserId))
          .thenAnswer((_) async => []);

      // Local unsynced queries (push phase)
      when(mockLocalChoirDataSource.getUnsyncedChoirs())
          .thenAnswer((_) async => []);
      when(mockLocalChoirDataSource.getUnsyncedMembers())
          .thenAnswer((_) async => []);
      when(mockLocalConcertDataSource.getUnsyncedConcerts())
          .thenAnswer((_) async => []);
      when(mockLocalConcertDataSource.getSyncedConcerts())
          .thenAnswer((_) async => {});
      when(mockLocalSongDataSource.getUnsyncedSongs())
          .thenAnswer((_) async => []);
      when(mockLocalSongDataSource.getSyncedSongs())
          .thenAnswer((_) async => {});
      when(mockLocalTrackDataSource.getUnsyncedTracks())
          .thenAnswer((_) async => []);
      when(mockLocalTrackDataSource.getSyncedTracks())
          .thenAnswer((_) async => {});
      when(mockLocalMarkerDataSource.getUnsyncedMarkerSets())
          .thenAnswer((_) async => []);
      when(mockLocalMarkerDataSource.getSyncedMarkerSets())
          .thenAnswer((_) async => {});
      when(mockLocalMarkerDataSource.getUnsyncedMarkers())
          .thenAnswer((_) async => []);
      when(mockLocalMarkerDataSource.getSyncedMarkers())
          .thenAnswer((_) async => {});
      when(mockLocalFavoriteTrackDataSource.getUnsyncedFavorites(testUserId))
          .thenAnswer((_) async => []);
      when(mockLocalFavoriteTrackDataSource.getSyncedFavorites(testUserId))
          .thenAnswer((_) async => {});

      // Cleanup methods (called at end of each sync step)
      when(mockLocalChoirDataSource.hardDeleteSyncedDeletedChoirs())
          .thenAnswer((_) async {});
      when(mockLocalChoirDataSource.hardDeleteSyncedDeletedMembers())
          .thenAnswer((_) async {});
      when(mockLocalFavoriteTrackDataSource.hardDeleteSyncedDeleted(testUserId))
          .thenAnswer((_) async {});
    }

    setUp(() {
      mockLocalChoirDataSource = MockLocalChoirDataSource();
      mockLocalConcertDataSource = MockLocalConcertDataSource();
      mockLocalSongDataSource = MockLocalSongDataSource();
      mockLocalTrackDataSource = MockLocalTrackDataSource();
      mockLocalMarkerDataSource = MockLocalMarkerDataSource();
      mockLocalFavoriteTrackDataSource = MockLocalFavoriteTrackDataSource();
      mockRemoteChoirDataSource = MockRemoteChoirDataSource();
      mockRemoteConcertDataSource = MockRemoteConcertDataSource();
      mockRemoteSongDataSource = MockRemoteSongDataSource();
      mockRemoteTrackDataSource = MockRemoteTrackDataSource();
      mockRemoteMarkerDataSource = MockRemoteMarkerDataSource();
      mockRemoteFavoriteTrackDataSource = MockRemoteFavoriteTrackDataSource();

      // Default choir sync stubs used by every sync run
      when(mockLocalChoirDataSource.getUnsyncedChoirs())
          .thenAnswer((_) async => []);
      when(mockLocalChoirDataSource.getSyncedChoirs())
          .thenAnswer((_) async => {});
      when(mockLocalChoirDataSource.getUnsyncedMembers())
          .thenAnswer((_) async => []);
      when(mockLocalChoirDataSource.getSyncedMembers())
          .thenAnswer((_) async => {});
      when(mockLocalChoirDataSource.hardDeleteSyncedDeletedChoirs())
          .thenAnswer((_) async {});
      when(mockLocalChoirDataSource.hardDeleteSyncedDeletedMembers())
          .thenAnswer((_) async {});
      when(mockLocalConcertDataSource.getSyncedConcerts())
          .thenAnswer((_) async => {});
      when(mockLocalConcertDataSource.getUnsyncedConcerts())
          .thenAnswer((_) async => []);
      when(mockLocalSongDataSource.getSyncedSongs())
          .thenAnswer((_) async => {});
      when(mockLocalSongDataSource.getUnsyncedSongs())
          .thenAnswer((_) async => []);
      when(mockLocalTrackDataSource.getSyncedTracks())
          .thenAnswer((_) async => {});
      when(mockLocalTrackDataSource.getUnsyncedTracks())
          .thenAnswer((_) async => []);
      when(mockLocalMarkerDataSource.getSyncedMarkerSets())
          .thenAnswer((_) async => {});
      when(mockLocalMarkerDataSource.getUnsyncedMarkerSets())
          .thenAnswer((_) async => []);
      when(mockLocalMarkerDataSource.getSyncedMarkers())
          .thenAnswer((_) async => {});
      when(mockLocalMarkerDataSource.getUnsyncedMarkers())
          .thenAnswer((_) async => []);
      when(mockLocalFavoriteTrackDataSource.getSyncedFavorites(any))
          .thenAnswer((_) async => {});
      when(mockLocalFavoriteTrackDataSource.getUnsyncedFavorites(any))
          .thenAnswer((_) async => []);
      when(mockRemoteFavoriteTrackDataSource.getFavorites(any))
          .thenAnswer((_) async => []);
      when(mockLocalTrackDataSource.hardDeleteSyncedDeleted())
          .thenAnswer((_) async {});
      when(mockLocalConcertDataSource.hardDeleteSyncedDeleted())
          .thenAnswer((_) async {});
      when(mockLocalSongDataSource.hardDeleteSyncedDeleted())
          .thenAnswer((_) async {});
      when(mockLocalMarkerDataSource.hardDeleteSyncedDeletedMarkerSets())
          .thenAnswer((_) async {});
      when(mockLocalMarkerDataSource.hardDeleteSyncedDeletedMarkers())
          .thenAnswer((_) async {});
      when(mockLocalFavoriteTrackDataSource.hardDeleteSyncedDeleted(any))
          .thenAnswer((_) async {});

      syncService = SyncService(
        localChoirDataSource: mockLocalChoirDataSource,
        localConcertDataSource: mockLocalConcertDataSource,
        localSongDataSource: mockLocalSongDataSource,
        localTrackDataSource: mockLocalTrackDataSource,
        localMarkerDataSource: mockLocalMarkerDataSource,
        localFavoriteTrackDataSource: mockLocalFavoriteTrackDataSource,
        remoteChoirDataSource: mockRemoteChoirDataSource,
        remoteConcertDataSource: mockRemoteConcertDataSource,
        remoteSongDataSource: mockRemoteSongDataSource,
        remoteTrackDataSource: mockRemoteTrackDataSource,
        remoteMarkerDataSource: mockRemoteMarkerDataSource,
        remoteFavoriteTrackDataSource: mockRemoteFavoriteTrackDataSource,
      );
    });

    group('syncFromRemote', () {
      test('should sync choirs from remote to local', () async {
        stubEmptySync();
        final now = DateTime.now();
        final testChoir = ChoirModel(
          id: 'choir-1',
          name: 'Test Choir',
          ownerId: testUserId,
          createdAt: now,
        updatedAt: now,
        );
        final testMember = ChoirMemberModel(
          choirId: 'choir-1',
          userId: testUserId,
          joinedAt: now,
          updatedAt: now,
        );

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async => [testChoir]);
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async => [testMember]);
        when(mockLocalChoirDataSource.upsertChoir(any, markForSync: false))
            .thenAnswer((_) async {});
        when(mockLocalChoirDataSource.upsertMember(any, markForSync: false))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockLocalChoirDataSource.upsertChoir(any, markForSync: false))
            .called(1);
        verify(mockLocalChoirDataSource.upsertMember(any, markForSync: false))
            .called(1);
      });

      test('should sync concerts from remote to local', () async {
        stubEmptySync();
        final now = DateTime.now();
        final testConcert = ConcertModel(
          id: 'concert-1',
          choirId: 'choir-1',
          choirName: 'Test Choir',
          name: 'Test Concert',
          concertDate: now,
          createdAt: now,
        updatedAt: now,
        );

        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => [testConcert]);
        when(mockLocalConcertDataSource.upsertConcert(any, markForSync: false))
            .thenAnswer((_) async => true);

        await syncService.syncFromRemote(testUserId);

        verify(
                mockLocalConcertDataSource.upsertConcert(any, markForSync: false))
            .called(1);
      });

      test('should sync songs from remote to local', () async {
        stubEmptySync();
        final now = DateTime.now();
        final testSong = SongModel(
          id: 'song-1',
          concertId: 'concert-1',
          title: 'Test Song',
          createdAt: now,
        updatedAt: now,
        );

        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => [testSong]);
        when(mockLocalSongDataSource.upsertSong(any, markForSync: false))
            .thenAnswer((_) async => true);

        await syncService.syncFromRemote(testUserId);

        verify(mockLocalSongDataSource.upsertSong(any, markForSync: false))
            .called(1);
      });

      test('should sync tracks from remote to local', () async {
        stubEmptySync();
        final now = DateTime.now();
        final testTrack = TrackModel(
          id: 'track-1',
          songId: 'song-1',
          name: 'Test Track',
          audioUrl: 'https://example.com/track.mp3',
          storagePath: '/tracks/track.mp3',
          durationMs: 180000,
          createdAt: now,
        updatedAt: now,
        );

        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => [testTrack]);
        when(mockLocalTrackDataSource.upsertTrack(any, markForSync: false))
            .thenAnswer((_) async => true);

        await syncService.syncFromRemote(testUserId);

        verify(mockLocalTrackDataSource.upsertTrack(any, markForSync: false))
            .called(1);
      });

      test('should call progress callback with correct states', () async {
        stubEmptySync();
        final progressStates = <SyncState>[];

        await syncService.syncFromRemote(
          testUserId,
          onProgress: (state) => progressStates.add(state),
        );

        expect(progressStates, isNotEmpty);
        expect(progressStates.first.status, SyncStatus.syncing);
        expect(progressStates.last.status, SyncStatus.success);
      });

      test('should report error state when remote fetch fails', () async {
        SyncState? errorState;

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenThrow(Exception('Network error'));

        await expectLater(
          syncService.syncFromRemote(
            testUserId,
            onProgress: (state) => errorState = state,
          ),
          throwsA(isA<Exception>()),
        );

        expect(errorState?.status, SyncStatus.error);
        expect(errorState?.message, contains('Sync failed'));
      });

      test('should handle empty remote data gracefully', () async {
        stubEmptySync();

        await syncService.syncFromRemote(testUserId);

        verifyNever(
            mockLocalChoirDataSource.upsertChoir(any, markForSync: false));
        verifyNever(
            mockLocalConcertDataSource.upsertConcert(any, markForSync: false));
      });


      test('should sync in correct FK order', () async {
        stubEmptySync();
        final callOrder = <String>[];

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async {
          callOrder.add('choirs');
          return [];
        });
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('choir_members');
          return [];
        });
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async {
          callOrder.add('concerts');
          return [];
        });
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('songs');
          return [];
        });
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('tracks');
          return [];
        });
        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('marker_sets');
          return [];
        });
        await syncService.syncFromRemote(testUserId);

        expect(callOrder.indexOf('choirs'),
            lessThan(callOrder.indexOf('concerts')));
        expect(callOrder.indexOf('concerts'),
            lessThan(callOrder.indexOf('songs')));
        expect(
            callOrder.indexOf('songs'), lessThan(callOrder.indexOf('tracks')));
        expect(callOrder.indexOf('tracks'),
            lessThan(callOrder.indexOf('marker_sets')));
      });
    });

    group('bidirectional sync - push-before-pull', () {
      test('should push unsynced track update when local is newer', () async {
        stubEmptySync();
        final now = DateTime.now();
        final localTrack = TrackModel(
          id: 'track-1',
          songId: 'song-1',
          name: 'Updated Name',
          audioUrl: 'https://example.com/track.mp3',
          storagePath: '/tracks/track.mp3',
          durationMs: 180000,
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now,
        );
        final remoteTrack = TrackModel(
          id: 'track-1',
          songId: 'song-1',
          name: 'Old Name',
          audioUrl: 'https://example.com/track.mp3',
          storagePath: '/tracks/track.mp3',
          durationMs: 180000,
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(minutes: 1)),
        );

        when(mockLocalTrackDataSource.getUnsyncedTracks())
            .thenAnswer((_) async => [localTrack]);
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => [remoteTrack]);
        when(mockRemoteTrackDataSource.updateTrack(any))
            .thenAnswer((_) async {});
        when(mockLocalTrackDataSource.markAsSynced(any, any))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockRemoteTrackDataSource.updateTrack(localTrack)).called(1);
        verify(mockLocalTrackDataSource.markAsSynced('track-1', localTrack.updatedAt)).called(1);
      });

      test('should NOT push track update when remote is newer', () async {
        stubEmptySync();
        final now = DateTime.now();
        final localTrack = TrackModel(
          id: 'track-1',
          songId: 'song-1',
          name: 'Old Name',
          audioUrl: 'https://example.com/track.mp3',
          storagePath: '/tracks/track.mp3',
          durationMs: 180000,
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(minutes: 1)),
        );
        final remoteTrack = TrackModel(
          id: 'track-1',
          songId: 'song-1',
          name: 'Updated Name',
          audioUrl: 'https://example.com/track.mp3',
          storagePath: '/tracks/track.mp3',
          durationMs: 180000,
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now,
        );

        when(mockLocalTrackDataSource.getUnsyncedTracks())
            .thenAnswer((_) async => [localTrack]);
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => [remoteTrack]);
        when(mockLocalTrackDataSource.upsertTrack(any, markForSync: false))
            .thenAnswer((_) async => true);

        await syncService.syncFromRemote(testUserId);

        // Should NOT push local to remote
        verifyNever(mockRemoteTrackDataSource.updateTrack(any));
        verifyNever(mockRemoteTrackDataSource.createTrack(any));
        // Remote value applied via upsertTrack(markForSync:false) which sets synced=true inline
        verify(mockLocalTrackDataSource.upsertTrack(any, markForSync: false)).called(1);
      });

      test('should push new local concert creation to remote', () async {
        stubEmptySync();
        final now = DateTime.now();
        final localConcert = ConcertModel(
          id: 'concert-new',
          choirId: 'choir-1',
          choirName: 'Test Choir',
          name: 'New Concert',
          concertDate: now,
          createdAt: now,
        updatedAt: now,
        );

        when(mockLocalConcertDataSource.getUnsyncedConcerts())
            .thenAnswer((_) async => [localConcert]);
        // Empty remote = new creation
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteConcertDataSource.createConcert(any))
            .thenAnswer((_) async {});
        when(mockLocalConcertDataSource.markAsSynced(any, any))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockRemoteConcertDataSource.createConcert(localConcert))
            .called(1);
        verify(mockLocalConcertDataSource.markAsSynced('concert-new', localConcert.updatedAt))
            .called(1);
      });

      test('should push new local song creation to remote', () async {
        stubEmptySync();
        final now = DateTime.now();
        final localSong = SongModel(
          id: 'song-new',
          concertId: 'concert-1',
          title: 'New Song',
          createdAt: now,
        updatedAt: now,
        );

        when(mockLocalSongDataSource.getUnsyncedSongs())
            .thenAnswer((_) async => [localSong]);
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteSongDataSource.createSong(any))
            .thenAnswer((_) async {});
        when(mockLocalSongDataSource.markAsSynced(any, any))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockRemoteSongDataSource.createSong(localSong)).called(1);
        verify(mockLocalSongDataSource.markAsSynced('song-new', localSong.updatedAt)).called(1);
      });
    });

    group('favorites sync', () {
      test('should push unsynced favorite addition to remote', () async {
        stubEmptySync();
        final now = DateTime.now();
        final localFavorite = FavoriteTrackModel(
          addedAt: now,
          updatedAt: now,
          track: TrackModel(
            id: 'track-1',
            songId: 'song-1',
            name: 'Soprano',
            createdAt: now,
            updatedAt: now,
          ),
        );

        when(mockLocalFavoriteTrackDataSource.getUnsyncedFavorites(testUserId))
            .thenAnswer((_) async => [localFavorite]);
        when(mockRemoteFavoriteTrackDataSource.getFavorites(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteFavoriteTrackDataSource.addFavorite(any, any, any, any))
            .thenAnswer((_) async {});
        when(mockLocalFavoriteTrackDataSource.markAsSynced(any, testUserId, any))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockRemoteFavoriteTrackDataSource.addFavorite(
          testUserId,
          'track-1',
          'song-1',
          localFavorite.updatedAt,
        )).called(1);
      });

      test('should push soft-deleted favorite as deletion to remote',
          () async {
        stubEmptySync();
        final now = DateTime.now();
        final localDeletedFavorite = FavoriteTrackModel(
          addedAt: now,
          updatedAt: now,
          deleted: true,
          track: TrackModel(
            id: 'track-1',
            songId: 'song-1',
            name: 'Soprano',
            createdAt: now,
            updatedAt: now,
          ),
        );
        final remoteFavorite = FavoriteTrackModel(
          addedAt: now,
          updatedAt: now,
          track: TrackModel(
            id: 'track-1',
            songId: 'song-1',
            name: 'Soprano',
            createdAt: now,
            updatedAt: now,
          ),
        );

        when(mockLocalFavoriteTrackDataSource.getUnsyncedFavorites(testUserId))
            .thenAnswer((_) async => [localDeletedFavorite]);
        when(mockRemoteFavoriteTrackDataSource.getFavorites(testUserId))
            .thenAnswer((_) async => [remoteFavorite]);
        when(mockRemoteFavoriteTrackDataSource.removeFavorite(any, any, any))
            .thenAnswer((_) async {});
        when(mockLocalFavoriteTrackDataSource.markAsSynced(any, testUserId, any))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        verify(mockRemoteFavoriteTrackDataSource.removeFavorite(
          testUserId,
          'track-1',
          localDeletedFavorite.updatedAt,
        )).called(1);
      });

    });

    group('marker set sync - Bug 2 regression', () {
      test('should preserve isTimeSynced: false during sync', () async {
        stubEmptySync();
        final now = DateTime.now();
        final remoteMarkerSet = MarkerSetModel(
          id: 'ms-1',
          trackId: 'track-1',
          name: 'My Markers',
          isShared: false,
          isTimeSynced: false, // This was the bug - it was defaulting to true
          createdByUserId: testUserId,
          createdAt: now,
        updatedAt: now,
        );

        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async => [remoteMarkerSet]);
        when(mockLocalMarkerDataSource.upsertMarkerSet(any, markForSync: false))
            .thenAnswer((_) async {});

        await syncService.syncFromRemote(testUserId);

        // Verify the marker set passed to upsert has isTimeSynced: false
        final captured = verify(mockLocalMarkerDataSource.upsertMarkerSet(
          captureAny,
          markForSync: false,
        )).captured;
        expect(captured, hasLength(1));
        final upsertedSet = captured.first as MarkerSetModel;
        expect(upsertedSet.isTimeSynced, isFalse);
      });
    });
  });

  group('SyncState', () {
    test('initial state should be idle', () {
      // Assert
      expect(SyncState.initial.status, SyncStatus.idle);
      expect(SyncState.initial.message, isNull);
      expect(SyncState.initial.progress, isNull);
    });

    test('syncing factory should create syncing state', () {
      // Act
      final state = SyncState.syncing(currentEntity: 'choirs', progress: 0.5);

      // Assert
      expect(state.status, SyncStatus.syncing);
      expect(state.currentEntity, 'choirs');
      expect(state.progress, 0.5);
    });

    test('success factory should create success state', () {
      // Act
      final state = SyncState.success(message: 'Done');

      // Assert
      expect(state.status, SyncStatus.success);
      expect(state.message, 'Done');
      expect(state.progress, 1.0);
    });

    test('error factory should create error state', () {
      // Act
      final state = SyncState.error('Something went wrong');

      // Assert
      expect(state.status, SyncStatus.error);
      expect(state.message, 'Something went wrong');
    });

    test('copyWith should create new instance with updated fields', () {
      // Arrange
      final original =
          SyncState.syncing(currentEntity: 'choirs', progress: 0.5);

      // Act
      final updated = original.copyWith(progress: 0.7);

      // Assert
      expect(updated.status, SyncStatus.syncing);
      expect(updated.currentEntity, 'choirs');
      expect(updated.progress, 0.7);
    });
  });
}
