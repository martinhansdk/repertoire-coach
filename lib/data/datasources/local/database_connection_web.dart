import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Open database connection for web platform (uses WASM + IndexedDB)
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    // Create database with IndexedDB storage (simple mode, no web worker)
    final database = await WasmDatabase.open(
      databaseName: 'repertoire_coach_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    return database.resolvedExecutor;
  });
}
