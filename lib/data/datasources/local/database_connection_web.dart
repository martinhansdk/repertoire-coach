import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

/// Open database connection for web platform (uses IndexedDB)
///
/// Note: This uses IndexedDB directly without SQLite WASM.
/// While this works, it has some limitations compared to SQLite.
/// For production, consider setting up WASM support for full SQLite compatibility.
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    return WebDatabase.withStorage(
      await DriftWebStorage.indexedDbIfSupported('repertoire_coach_db'),
    );
  });
}
