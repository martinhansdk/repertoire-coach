import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/errors/marker_invariant_exception.dart';
import '../../models/marker_model.dart';
import '../../models/marker_set_model.dart';
import 'database.dart' as db;

/// Local data source for marker and marker set operations using Drift/SQLite.
///
/// Marker rows are stored as a JSON payload on marker_sets.markers_json.
class LocalMarkerDataSource {
  final db.AppDatabase _database;

  LocalMarkerDataSource(this._database);

  // ==================== MarkerSet Operations ====================

  Future<List<MarkerSetModel>> getMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) async {
    final query = _database.select(_database.markerSets)
      ..where((ms) => ms.trackId.equals(trackId))
      ..where((ms) => ms.deleted.equals(false));

    if (userId != null) {
      query.where((ms) =>
          ms.isShared.equals(true) | ms.createdByUserId.equals(userId));
    }

    query.orderBy([
      (ms) => OrderingTerm(expression: ms.isShared, mode: OrderingMode.desc),
      (ms) => OrderingTerm.asc(ms.name),
    ]);

    final sets = await query.get();
    return sets.map((s) => MarkerSetModel.fromDrift(s)).toList();
  }

  Stream<List<MarkerSetModel>> watchMarkerSetsByTrack(
    String trackId, {
    String? userId,
  }) {
    final query = _database.select(_database.markerSets)
      ..where((ms) => ms.trackId.equals(trackId))
      ..where((ms) => ms.deleted.equals(false));

    if (userId != null) {
      query.where((ms) =>
          ms.isShared.equals(true) | ms.createdByUserId.equals(userId));
    }

    query.orderBy([
      (ms) => OrderingTerm(expression: ms.isShared, mode: OrderingMode.desc),
      (ms) => OrderingTerm.asc(ms.name),
    ]);

    return query.watch().map(
          (sets) => sets.map((s) => MarkerSetModel.fromDrift(s)).toList(),
        );
  }

  Future<MarkerSetModel?> getMarkerSetById(String id) async {
    final markerSet = await (_database.select(_database.markerSets)
          ..where((ms) => ms.id.equals(id))
          ..where((ms) => ms.deleted.equals(false)))
        .getSingleOrNull();

    return markerSet != null ? MarkerSetModel.fromDrift(markerSet) : null;
  }

  Future<void> upsertMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    if (!markForSync) {
      final existing = await (_database.select(_database.markerSets)
            ..where((ms) => ms.id.equals(markerSet.id)))
          .getSingleOrNull();

      if (existing != null && existing.deleted && !existing.synced) {
        return;
      }
    }

    await _database.into(_database.markerSets).insertOnConflictUpdate(
          markerSet.toDriftCompanion(markForSync: markForSync),
        );
  }

  Future<void> insertMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    await _database.into(_database.markerSets).insert(
          markerSet.toDriftCompanion(markForSync: markForSync),
        );
  }

  Future<bool> updateMarkerSet(
    MarkerSetModel markerSet, {
    bool markForSync = true,
  }) async {
    final rowsAffected = await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(markerSet.id)))
        .write(markerSet.toDriftCompanion(markForSync: markForSync));

    return rowsAffected > 0;
  }

  Future<void> deleteMarkerSet(String id) async {
    await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(id)))
        .write(
      db.MarkerSetsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: const Value(false),
      ),
    );
  }

  Future<List<MarkerSetModel>> getUnsyncedMarkerSets() async {
    final sets = await (_database.select(_database.markerSets)
          ..where((ms) => ms.synced.equals(false)))
        .get();

    return sets.map((s) => MarkerSetModel.fromDrift(s)).toList();
  }

  Future<void> markMarkerSetAsSynced(String id) async {
    await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(id)))
        .write(const db.MarkerSetsCompanion(synced: Value(true)));
  }

  Future<void> hardDeleteMarkerSetsNotIn(Set<String> keepIds) async {
    await _database.hardDeleteMarkerSetsNotIn(keepIds);
  }

  Future<void> hardDeleteSyncedDeletedMarkerSets() async {
    await (_database.delete(_database.markerSets)
          ..where((ms) => ms.synced.equals(true))
          ..where((ms) => ms.deleted.equals(true)))
        .go();
  }

  Future<Map<String, MarkerSetModel>> getSyncedMarkerSets() async {
    final sets = await (_database.select(_database.markerSets)
          ..where((ms) => ms.synced.equals(true)))
        .get();

    return Map.fromEntries(
      sets.map((s) => MapEntry(s.id, MarkerSetModel.fromDrift(s))),
    );
  }

  // ==================== Marker Operations (JSON Payload) ====================

  Future<List<MarkerModel>> getMarkersByMarkerSet(String markerSetId) async {
    final markerSet = await (_database.select(_database.markerSets)
          ..where((ms) => ms.id.equals(markerSetId))
          ..where((ms) => ms.deleted.equals(false)))
        .getSingleOrNull();
    if (markerSet == null) {
      return const [];
    }

    return _decodeMarkers(markerSetId, markerSet.markersJson);
  }

  Stream<List<MarkerModel>> watchMarkersByMarkerSet(String markerSetId) {
    return (_database.select(_database.markerSets)
          ..where((ms) => ms.id.equals(markerSetId))
          ..where((ms) => ms.deleted.equals(false)))
        .watchSingleOrNull()
        .map((markerSet) {
      if (markerSet == null) {
        return <MarkerModel>[];
      }
      return _decodeMarkers(markerSetId, markerSet.markersJson);
    });
  }

  Future<MarkerModel?> getMarkerById(String id) async {
    final parsed = _parseSyntheticMarkerId(id);
    if (parsed == null) {
      return null;
    }

    final markers = await getMarkersByMarkerSet(parsed.markerSetId);
    if (parsed.index < 0 || parsed.index >= markers.length) {
      return null;
    }

    return markers[parsed.index];
  }

  Future<void> upsertMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    await _database.transaction(() async {
      final markerSet = await (_database.select(_database.markerSets)
            ..where((ms) => ms.id.equals(marker.markerSetId))
            ..where((ms) => ms.deleted.equals(false)))
          .getSingleOrNull();
      if (markerSet == null) {
        return;
      }

      final payload = _decodeRawPayload(markerSet.markersJson).toList();
      final index = marker.order;
      while (payload.length <= index) {
        payload.add(<String, dynamic>{'label': '', 'position_ms': null});
      }

      payload[index] = <String, dynamic>{
        'label': marker.label,
        'position_ms': marker.positionMs,
      };

      await _writePayload(
        markerSetId: marker.markerSetId,
        payload: payload,
        markForSync: markForSync,
      );
    });
  }

  Future<void> insertMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    await upsertMarker(marker, markForSync: markForSync);
  }

  Future<bool> updateMarker(
    MarkerModel marker, {
    bool markForSync = true,
  }) async {
    await upsertMarker(marker, markForSync: markForSync);
    return true;
  }

  Future<void> deleteMarker(String id) async {
    final parsed = _parseSyntheticMarkerId(id);
    if (parsed == null) {
      return;
    }

    await _database.transaction(() async {
      final markerSet = await (_database.select(_database.markerSets)
            ..where((ms) => ms.id.equals(parsed.markerSetId))
            ..where((ms) => ms.deleted.equals(false)))
          .getSingleOrNull();
      if (markerSet == null) {
        return;
      }

      final payload = _decodeRawPayload(markerSet.markersJson).toList();
      if (parsed.index < 0 || parsed.index >= payload.length) {
        return;
      }
      payload.removeAt(parsed.index);

      await _writePayload(
        markerSetId: parsed.markerSetId,
        payload: payload,
        markForSync: true,
      );
    });
  }

  Future<void> deleteMarkersByMarkerSet(String markerSetId) async {
    await _writePayload(
      markerSetId: markerSetId,
      payload: const [],
      markForSync: true,
    );
  }

  /// Replace the entire marker payload in one write.
  Future<void> replaceMarkersByMarkerSet(
    String markerSetId,
    List<MarkerModel> markers, {
    bool markForSync = true,
  }) async {
    final payload = markers
        .map((marker) => <String, dynamic>{
              'label': marker.label,
              'position_ms': marker.positionMs,
            })
        .toList(growable: false);
    await _writePayload(
      markerSetId: markerSetId,
      payload: payload,
      markForSync: markForSync,
    );
  }

  // Legacy marker sync methods are now no-ops because marker data is synced
  // as part of marker_sets payload.
  Future<List<MarkerModel>> getUnsyncedMarkers() async => const [];

  Future<void> hardDeleteMarkersNotIn(Set<String> keepIds) async {}

  Future<void> markMarkerAsSynced(String id) async {}

  Future<void> hardDeleteSyncedDeletedMarkers() async {}

  Future<Map<String, MarkerModel>> getSyncedMarkers() async =>
      <String, MarkerModel>{};

  Future<void> _writePayload({
    required String markerSetId,
    required List<Map<String, dynamic>> payload,
    required bool markForSync,
  }) async {
    _assertMonotonicPositions(payload);

    final rowsAffected = await (_database.update(_database.markerSets)
          ..where((ms) => ms.id.equals(markerSetId))
          ..where((ms) => ms.deleted.equals(false)))
        .write(
      db.MarkerSetsCompanion(
        markersJson: Value(jsonEncode(payload)),
        updatedAt: Value(DateTime.now().toUtc()),
        synced: Value(!markForSync),
      ),
    );

    if (rowsAffected == 0) {
      throw StateError('Marker set $markerSetId not found');
    }
  }

  void _assertMonotonicPositions(List<Map<String, dynamic>> payload) {
    int? previousPosition;
    for (var i = 0; i < payload.length; i++) {
      final positionMs = payload[i]['position_ms'] as int?;
      if (positionMs == null) {
        continue;
      }
      if (previousPosition != null && positionMs < previousPosition) {
        throw MarkerInvariantException(
          'Markers must be monotonic by order. Index $i has $positionMs, '
          'previous synced marker had $previousPosition.',
        );
      }
      previousPosition = positionMs;
    }
  }

  List<MarkerModel> _decodeMarkers(String markerSetId, String markersJson) {
    final payload = _decodeRawPayload(markersJson);
    final now = DateTime.now().toUtc();

    return List<MarkerModel>.generate(payload.length, (index) {
      final item = payload[index];
      return MarkerModel(
        id: _buildSyntheticMarkerId(markerSetId, index),
        markerSetId: markerSetId,
        label: item['label'] as String? ?? '',
        positionMs: item['position_ms'] as int?,
        order: index,
        createdAt: now,
        updatedAt: now,
      );
    }, growable: false);
  }

  List<Map<String, dynamic>> _decodeRawPayload(String markersJson) {
    final decoded = jsonDecode(markersJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (entry) => <String, dynamic>{
            'label': entry['label'] as String? ?? '',
            'position_ms': entry['position_ms'] as int?,
          },
        )
        .toList(growable: false);
  }

  String _buildSyntheticMarkerId(String markerSetId, int index) {
    return '$markerSetId:$index';
  }

  ({String markerSetId, int index})? _parseSyntheticMarkerId(String id) {
    final separator = id.lastIndexOf(':');
    if (separator <= 0 || separator == id.length - 1) {
      return null;
    }
    final markerSetId = id.substring(0, separator);
    final index = int.tryParse(id.substring(separator + 1));
    if (index == null) {
      return null;
    }
    return (markerSetId: markerSetId, index: index);
  }
}
