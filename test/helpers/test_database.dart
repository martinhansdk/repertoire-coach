import 'package:drift/native.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart';

/// Creates an in-memory database for testing
///
/// This database exists only in memory and is destroyed when closed.
/// Perfect for fast, isolated tests that need database functionality.
///
/// Usage:
/// ```dart
/// final testDb = createTestDatabase();
/// final container = ProviderContainer(
///   overrides: [
///     databaseProvider.overrideWithValue(testDb),
///   ],
/// );
/// // ... run tests ...
/// container.dispose();
/// testDb.close();
/// ```
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
