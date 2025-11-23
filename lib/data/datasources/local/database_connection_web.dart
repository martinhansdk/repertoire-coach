import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Open database connection for web platform (uses IndexedDB)
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    final storage = DriftWebStorage.indexedDb('repertoire_coach_db');
    return WebDatabase.withStorage(storage);
  });
}
