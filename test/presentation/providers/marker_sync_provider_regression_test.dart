import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/local/local_marker_data_source.dart';
import 'package:repertoire_coach/data/models/marker_model.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';
import 'package:repertoire_coach/domain/entities/marker.dart';
import 'package:repertoire_coach/domain/entities/marker_set.dart';
import 'package:repertoire_coach/domain/repositories/marker_repository.dart';
import 'package:repertoire_coach/presentation/providers/marker_sync_provider.dart';

import '../../helpers/test_database.dart';

class _LocalOnlyMarkerRepository implements MarkerRepository {
  _LocalOnlyMarkerRepository(this._localDataSource);

  final LocalMarkerDataSource _localDataSource;

  @override
  Future<void> createMarker(Marker marker) async {
    await _localDataSource.insertMarker(MarkerModel.fromEntity(marker));
  }

  @override
  Future<void> createMarkerSet(MarkerSet markerSet) async {
    await _localDataSource.insertMarkerSet(MarkerSetModel.fromEntity(markerSet));
  }

  @override
  Future<void> deleteMarker(String markerId) async {
    await _localDataSource.deleteMarker(markerId);
  }

  @override
  Future<void> deleteMarkerSet(String markerSetId) async {
    await _localDataSource.deleteMarkerSet(markerSetId);
  }

  @override
  Future<void> deleteMarkersByMarkerSet(String markerSetId) async {
    await _localDataSource.deleteMarkersByMarkerSet(markerSetId);
  }

  @override
  Future<Marker?> getMarkerById(String markerId) async {
    final model = await _localDataSource.getMarkerById(markerId);
    return model?.toEntity();
  }

  @override
  Future<MarkerSet?> getMarkerSetById(String markerSetId) async {
    final model = await _localDataSource.getMarkerSetById(markerSetId);
    return model?.toEntity();
  }

  @override
  Future<List<Marker>> getMarkersByMarkerSet(String markerSetId) async {
    final models = await _localDataSource.getMarkersByMarkerSet(markerSetId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<MarkerSet>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) async {
    final models =
        await _localDataSource.getMarkerSetsByTrack(trackId, userId: userId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<bool> updateMarker(Marker marker) async {
    return _localDataSource.updateMarker(MarkerModel.fromEntity(marker));
  }

  @override
  Future<bool> updateMarkerSet(MarkerSet markerSet) async {
    return _localDataSource.updateMarkerSet(MarkerSetModel.fromEntity(markerSet));
  }
}

void main() {
  group('MarkerSync regression', () {
    test(
      're-sync after inserting a middle line can surface duplicated markers after stale remote pull',
      () async {
        final database = createTestDatabase();
        final localDataSource = LocalMarkerDataSource(database);
        final repository = _LocalOnlyMarkerRepository(localDataSource);
        final now = DateTime.utc(2026, 1, 1);

        addTearDown(database.close);

        await repository.createMarkerSet(
          MarkerSet(
            id: 'set-1',
            trackId: 'track-1',
            name: 'Structure',
            isShared: true,
            isTimeSynced: true,
            createdByUserId: 'owner-user',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.createMarker(
          Marker(
            id: 'old-1',
            markerSetId: 'set-1',
            label: 'Intro',
            positionMs: 1000,
            order: 0,
            createdAt: now,
          ),
        );
        await repository.createMarker(
          Marker(
            id: 'old-2',
            markerSetId: 'set-1',
            label: 'Verse',
            positionMs: 2000,
            order: 1,
            createdAt: now,
          ),
        );
        await repository.createMarker(
          Marker(
            id: 'old-3',
            markerSetId: 'set-1',
            label: 'Chorus',
            positionMs: 3000,
            order: 2,
            createdAt: now,
          ),
        );

        final notifier = MarkerSyncNotifier(
          markerRepository: repository,
          trackId: 'track-1',
          markerSetId: 'set-1',
        );

        await notifier.startSyncFromText('Intro\nBridge\nVerse\nChorus');
        notifier.syncNextMarker(1000);
        notifier.syncNextMarker(1500);
        notifier.syncNextMarker(2000);
        notifier.syncNextMarker(3000);
        await notifier.save();

        // Simulate a later remote sync pull that still contains pre-edit markers.
        // This matches the shared-marker-set RLS mismatch where deletes can fail
        // for non-owners, leaving stale rows in Supabase.
        await localDataSource.upsertMarker(
          MarkerModel(
            id: 'old-1',
            markerSetId: 'set-1',
            label: 'Intro',
            positionMs: 1000,
            order: 0,
            createdAt: now,
          ),
          markForSync: false,
        );
        await localDataSource.upsertMarker(
          MarkerModel(
            id: 'old-2',
            markerSetId: 'set-1',
            label: 'Verse',
            positionMs: 2000,
            order: 1,
            createdAt: now,
          ),
          markForSync: false,
        );
        await localDataSource.upsertMarker(
          MarkerModel(
            id: 'old-3',
            markerSetId: 'set-1',
            label: 'Chorus',
            positionMs: 3000,
            order: 2,
            createdAt: now,
          ),
          markForSync: false,
        );

        final markers = await repository.getMarkersByMarkerSet('set-1');
        final labels =
            markers.map((marker) => marker.label).where((label) => label.isNotEmpty).toList();

        // Expected behavior: no duplicates should appear in the audio player list.
        expect(labels.toSet().length, labels.length);
      },
    );
  });
}
