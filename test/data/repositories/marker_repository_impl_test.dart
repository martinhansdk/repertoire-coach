import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/core/services/supabase_service.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/datasources/remote/remote_marker_data_source.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';
import 'package:repertoire_coach/data/repositories/marker_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';

@GenerateMocks([RemoteMarkerDataSource, SupabaseService])
import 'marker_repository_impl_test.mocks.dart';

void main() {
  group('MarkerRepositoryImpl', () {
    late db.AppDatabase database;
    late LocalMarkerDataSource localDS;
    late MockRemoteMarkerDataSource mockRemoteDS;
    late MockSupabaseService mockSupabaseService;
    late MarkerRepositoryImpl repository;

    final now = DateTime(2024, 1, 1);

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      localDS = LocalMarkerDataSource(database);
      mockRemoteDS = MockRemoteMarkerDataSource();
      mockSupabaseService = MockSupabaseService();

      when(mockSupabaseService.isAuthenticated).thenReturn(true);
      when(mockRemoteDS.updateMarkerSet(any)).thenAnswer((_) async {});

      repository = MarkerRepositoryImpl(localDS, mockRemoteDS, mockSupabaseService);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> seedMarkerSet({required bool isTimeSynced, String id = 'set-1'}) async {
      await localDS.insertMarkerSet(MarkerSetModel(
        id: id,
        trackId: 'track-1',
        name: 'Test Set',
        isShared: false,
        isTimeSynced: isTimeSynced,
        createdByUserId: 'user-1',
        createdAt: now,
        updatedAt: now,
      ));
    }

    List<Marker> allSynced() => [
          Marker(
            id: 'm1',
            markerSetId: 'set-1',
            label: 'intro',
            positionMs: 1000,
            order: 0,
            createdAt: now,
            updatedAt: now,
          ),
          Marker(
            id: 'm2',
            markerSetId: 'set-1',
            label: 'verse',
            positionMs: 2000,
            order: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];

    List<Marker> partiallyUnsynced() => [
          Marker(
            id: 'm1',
            markerSetId: 'set-1',
            label: 'intro',
            positionMs: 1000,
            order: 0,
            createdAt: now,
            updatedAt: now,
          ),
          Marker(
            id: 'm2',
            markerSetId: 'set-1',
            label: 'verse',
            positionMs: null,
            order: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];

    group('createMarkerSet — remote isTimeSynced reflects payload', () {
      // Regression: createMarkerSet was copying isTimeSynced from the entity
      // (e.g. the source of a copy) but always sending markers_json: [] because
      // fromEntity() hard-codes it. An empty array is vacuously time-synced
      // (true), so sending is_time_synced: false violates the Supabase check
      // constraint marker_sets_is_time_synced_matches_payload.

      MarkerSet makeSet({required bool isTimeSynced, String id = 'new-set'}) =>
          MarkerSet(
            id: id,
            trackId: 'track-1',
            name: 'New Set',
            isShared: false,
            isTimeSynced: isTimeSynced,
            createdByUserId: 'user-1',
            createdAt: now,
            updatedAt: now,
          );

      setUp(() {
        when(mockRemoteDS.createMarkerSet(any)).thenAnswer((_) async {});
      });

      test(
          'sends isTimeSynced=true when entity has isTimeSynced=false '
          'but markers_json is empty (vacuously synced)', () async {
        await repository.createMarkerSet(makeSet(isTimeSynced: false));

        final captured =
            verify(mockRemoteDS.createMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, true);
      });

      test('sends isTimeSynced=true when entity has isTimeSynced=true and markers_json is empty',
          () async {
        await repository.createMarkerSet(makeSet(isTimeSynced: true));

        final captured =
            verify(mockRemoteDS.createMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, true);
      });
    });

    group('updateMarkerSet — remote isTimeSynced reflects payload', () {
      // Regression: updateMarkerSet was copying isTimeSynced from the entity
      // (loaded from the local DB, which may be stale) while using the fresh
      // markersJson from the DB. These can disagree after _syncMarkerSetPayload
      // corrects isTimeSynced remotely without updating the local column.

      setUp(() {
        when(mockRemoteDS.updateMarkerSet(any)).thenAnswer((_) async {});
      });

      test(
          'sends isTimeSynced=true when entity has isTimeSynced=false '
          'but all markers in local DB have positions', () async {
        // Seed with isTimeSynced=false but fully-positioned markers_json
        await localDS.insertMarkerSet(MarkerSetModel(
          id: 'set-u',
          trackId: 'track-1',
          name: 'My Set',
          isShared: false,
          isTimeSynced: false, // stale local value
          createdByUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
          markersJson:
              '[{"label":"intro","position_ms":1000},{"label":"verse","position_ms":2000}]',
        ));

        // Entity loaded from DB carries the stale isTimeSynced=false
        final entity = MarkerSet(
          id: 'set-u',
          trackId: 'track-1',
          name: 'My Set (renamed)',
          isShared: false,
          isTimeSynced: false, // stale
          createdByUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
        );

        await repository.updateMarkerSet(entity);

        final captured =
            verify(mockRemoteDS.updateMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, true);
      });

      test(
          'sends isTimeSynced=false when some markers lack positions, '
          'even when entity has isTimeSynced=true', () async {
        await localDS.insertMarkerSet(MarkerSetModel(
          id: 'set-u',
          trackId: 'track-1',
          name: 'My Set',
          isShared: false,
          isTimeSynced: true, // stale local value
          createdByUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
          markersJson:
              '[{"label":"intro","position_ms":1000},{"label":"verse","position_ms":null}]',
        ));

        final entity = MarkerSet(
          id: 'set-u',
          trackId: 'track-1',
          name: 'My Set (renamed)',
          isShared: false,
          isTimeSynced: true, // stale
          createdByUserId: 'user-1',
          createdAt: now,
          updatedAt: now,
        );

        await repository.updateMarkerSet(entity);

        final captured =
            verify(mockRemoteDS.updateMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, false);
      });
    });

    group('replaceMarkersByMarkerSet — remote isTimeSynced reflects payload', () {
      // Regression: _syncMarkerSetPayload was sending the stale is_time_synced
      // from the local DB instead of computing it from the just-updated
      // markers_json payload. This violated the Supabase check constraint
      // marker_sets_is_time_synced_matches_payload.

      test(
          'sends isTimeSynced=true when all non-empty markers have positions, '
          'even when local DB has isTimeSynced=false', () async {
        await seedMarkerSet(isTimeSynced: false);

        await repository.replaceMarkersByMarkerSet('set-1', allSynced());

        final captured = verify(mockRemoteDS.updateMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, true);
      });

      test(
          'sends isTimeSynced=false when some non-empty markers lack positions, '
          'even when local DB has isTimeSynced=true', () async {
        await seedMarkerSet(isTimeSynced: true);

        await repository.replaceMarkersByMarkerSet('set-1', partiallyUnsynced());

        final captured = verify(mockRemoteDS.updateMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, false);
      });

      test('sends isTimeSynced=true when DB is already true and all markers synced', () async {
        await seedMarkerSet(isTimeSynced: true);

        await repository.replaceMarkersByMarkerSet('set-1', allSynced());

        final captured = verify(mockRemoteDS.updateMarkerSet(captureAny)).captured;
        final sent = captured.last as MarkerSetModel;
        expect(sent.isTimeSynced, true);
      });
    });
  });
}
