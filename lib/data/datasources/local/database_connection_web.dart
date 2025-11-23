import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Open database connection for web platform (uses IndexedDB)
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    return WebDatabase.withStorage(
      await DriftWebStorage.indexedDbIfSupported('repertoire_coach_db'),
    );
  });
}
