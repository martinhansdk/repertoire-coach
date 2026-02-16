import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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
import 'package:repertoire_coach/data/datasources/remote/remote_user_playback_state_data_source.dart';
import 'package:repertoire_coach/data/models/choir_member_model.dart';
import 'package:repertoire_coach/data/models/choir_model.dart';
import 'package:repertoire_coach/data/models/concert_model.dart';
import 'package:repertoire_coach/data/models/song_model.dart';
import 'package:repertoire_coach/data/models/track_model.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([
  LocalChoirDataSource,
  LocalConcertDataSource,
  LocalSongDataSource,
  LocalTrackDataSource,
  LocalMarkerDataSource,
  LocalUserPlaybackStateDataSource,
  RemoteChoirDataSource,
  RemoteConcertDataSource,
  RemoteSongDataSource,
  RemoteTrackDataSource,
  RemoteMarkerDataSource,
  RemoteUserPlaybackStateDataSource,
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
    late MockLocalUserPlaybackStateDataSource mockLocalPlaybackStateDataSource;
    late MockRemoteChoirDataSource mockRemoteChoirDataSource;
    late MockRemoteConcertDataSource mockRemoteConcertDataSource;
    late MockRemoteSongDataSource mockRemoteSongDataSource;
    late MockRemoteTrackDataSource mockRemoteTrackDataSource;
    late MockRemoteMarkerDataSource mockRemoteMarkerDataSource;
    late MockRemoteUserPlaybackStateDataSource mockRemotePlaybackStateDataSource;

    const testUserId = 'user-123';

    setUp(() {
      mockLocalChoirDataSource = MockLocalChoirDataSource();
      mockLocalConcertDataSource = MockLocalConcertDataSource();
      mockLocalSongDataSource = MockLocalSongDataSource();
      mockLocalTrackDataSource = MockLocalTrackDataSource();
      mockLocalMarkerDataSource = MockLocalMarkerDataSource();
      mockLocalPlaybackStateDataSource = MockLocalUserPlaybackStateDataSource();
      mockRemoteChoirDataSource = MockRemoteChoirDataSource();
      mockRemoteConcertDataSource = MockRemoteConcertDataSource();
      mockRemoteSongDataSource = MockRemoteSongDataSource();
      mockRemoteTrackDataSource = MockRemoteTrackDataSource();
      mockRemoteMarkerDataSource = MockRemoteMarkerDataSource();
      mockRemotePlaybackStateDataSource =
          MockRemoteUserPlaybackStateDataSource();

      // Stub hardDeleteTracksNotIn for all tests (called during track sync)
      when(mockLocalTrackDataSource.hardDeleteTracksNotIn(any))
          .thenAnswer((_) async {});

      syncService = SyncService(
        localChoirDataSource: mockLocalChoirDataSource,
        localConcertDataSource: mockLocalConcertDataSource,
        localSongDataSource: mockLocalSongDataSource,
        localTrackDataSource: mockLocalTrackDataSource,
        localMarkerDataSource: mockLocalMarkerDataSource,
        localPlaybackStateDataSource: mockLocalPlaybackStateDataSource,
        remoteChoirDataSource: mockRemoteChoirDataSource,
        remoteConcertDataSource: mockRemoteConcertDataSource,
        remoteSongDataSource: mockRemoteSongDataSource,
        remoteTrackDataSource: mockRemoteTrackDataSource,
        remoteMarkerDataSource: mockRemoteMarkerDataSource,
        remotePlaybackStateDataSource: mockRemotePlaybackStateDataSource,
      );
    });

    group('syncFromRemote', () {
      test('should sync choirs from remote to local', () async {
        // Arrange
        final now = DateTime.now();
        final testChoir = ChoirModel(
          id: 'choir-1',
          name: 'Test Choir',
          ownerId: testUserId,
          createdAt: now,
        );
        final testMember = ChoirMemberModel(
          choirId: 'choir-1',
          userId: testUserId,
          joinedAt: now,
        );

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async => [testChoir]);
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async => [testMember]);
        when(mockLocalChoirDataSource.upsertChoir(any, markForSync: false))
            .thenAnswer((_) async {});
        when(mockLocalChoirDataSource.upsertMember(any, markForSync: false))
            .thenAnswer((_) async {});

        // Set up other data sources to return empty lists
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act
        await syncService.syncFromRemote(testUserId);

        // Assert
        verify(mockLocalChoirDataSource.upsertChoir(any, markForSync: false))
            .called(1);
        verify(mockLocalChoirDataSource.upsertMember(any, markForSync: false))
            .called(1);
      });

      test('should sync concerts from remote to local', () async {
        // Arrange
        final now = DateTime.now();
        final testConcert = ConcertModel(
          id: 'concert-1',
          choirId: 'choir-1',
          choirName: 'Test Choir',
          name: 'Test Concert',
          concertDate: now,
          createdAt: now,
        );

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => [testConcert]);
        when(mockLocalConcertDataSource.upsertConcert(any, markForSync: false))
            .thenAnswer((_) async => true);

        // Set up other data sources to return empty lists
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act
        await syncService.syncFromRemote(testUserId);

        // Assert
        verify(mockLocalConcertDataSource.upsertConcert(any, markForSync: false))
            .called(1);
      });

      test('should sync songs from remote to local', () async {
        // Arrange
        final now = DateTime.now();
        final testSong = SongModel(
          id: 'song-1',
          concertId: 'concert-1',
          title: 'Test Song',
          createdAt: now,
          updatedAt: now,
        );

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => [testSong]);
        when(mockLocalSongDataSource.upsertSong(any, markForSync: false))
            .thenAnswer((_) async => true);

        // Set up other data sources to return empty lists
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act
        await syncService.syncFromRemote(testUserId);

        // Assert
        verify(mockLocalSongDataSource.upsertSong(any, markForSync: false))
            .called(1);
      });

      test('should sync tracks from remote to local', () async {
        // Arrange
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

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteChoirDataSource.getChoirMembersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteConcertDataSource.getConcerts(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteSongDataSource.getSongsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteTrackDataSource.getTracksForUser(testUserId))
            .thenAnswer((_) async => [testTrack]);
        when(mockLocalTrackDataSource.upsertTrack(any, markForSync: false))
            .thenAnswer((_) async => true);

        // Set up other data sources to return empty lists
        when(mockRemoteMarkerDataSource.getMarkerSetsForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act
        await syncService.syncFromRemote(testUserId);

        // Assert
        verify(mockLocalTrackDataSource.upsertTrack(any, markForSync: false))
            .called(1);
      });

      test('should call progress callback with correct states', () async {
        // Arrange
        final progressStates = <SyncState>[];

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
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act
        await syncService.syncFromRemote(
          testUserId,
          onProgress: (state) => progressStates.add(state),
        );

        // Assert
        expect(progressStates, isNotEmpty);
        expect(progressStates.first.status, SyncStatus.syncing);
        expect(progressStates.last.status, SyncStatus.success);
      });

      test('should report error state when remote fetch fails', () async {
        // Arrange
        SyncState? errorState;

        when(mockRemoteChoirDataSource.getChoirs(testUserId))
            .thenThrow(Exception('Network error'));

        // Act & Assert
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
        // Arrange
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
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async => []);
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async => []);

        // Act & Assert - should complete without throwing
        await syncService.syncFromRemote(testUserId);

        // Verify no upserts were called
        verifyNever(mockLocalChoirDataSource.upsertChoir(any, markForSync: false));
        verifyNever(mockLocalConcertDataSource.upsertConcert(any, markForSync: false));
      });

      test('should sync in correct FK order', () async {
        // Arrange
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
        when(mockRemoteMarkerDataSource.getMarkersForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('markers');
          return [];
        });
        when(mockRemotePlaybackStateDataSource
                .getPlaybackStatesForUser(testUserId))
            .thenAnswer((_) async {
          callOrder.add('playback_states');
          return [];
        });

        // Act
        await syncService.syncFromRemote(testUserId);

        // Assert - verify order respects FK dependencies
        expect(callOrder.indexOf('choirs'),
            lessThan(callOrder.indexOf('concerts')));
        expect(callOrder.indexOf('concerts'),
            lessThan(callOrder.indexOf('songs')));
        expect(
            callOrder.indexOf('songs'), lessThan(callOrder.indexOf('tracks')));
        expect(callOrder.indexOf('tracks'),
            lessThan(callOrder.indexOf('marker_sets')));
        expect(callOrder.indexOf('marker_sets'),
            lessThan(callOrder.indexOf('markers')));
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
