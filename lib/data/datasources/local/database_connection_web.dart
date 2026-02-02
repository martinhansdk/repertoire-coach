import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Open database connection for web platform (uses SQLite WASM)
///
/// This uses sql.js (SQLite compiled to WebAssembly) for full SQLite
/// compatibility on web platforms.
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    // ignore: avoid_print
    print('DEBUG: Starting WASM database initialization...');

    try {
      final result = await WasmDatabase.open(
        databaseName: 'repertoire_coach_db',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.dart.js'),
      );

      // ignore: avoid_print
      print('DEBUG: WASM database opened successfully');
      // ignore: avoid_print
      print('DEBUG: Implementation: ${result.chosenImplementation}');

      if (result.missingFeatures.isNotEmpty) {
        // ignore: avoid_print
        print('Using ${result.chosenImplementation} due to missing browser '
            'features: ${result.missingFeatures}');
      }

      return result.resolvedExecutor;
    } catch (e, st) {
      // ignore: avoid_print
      print('DEBUG: WASM database initialization FAILED: $e');
      // ignore: avoid_print
      print('DEBUG: Stack trace: $st');
      rethrow;
    }
  });
}
