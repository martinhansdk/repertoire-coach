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
