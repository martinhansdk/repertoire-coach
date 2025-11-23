import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Open database connection for native platforms (Android, iOS, Desktop)
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'repertoire_coach.db'));
    return NativeDatabase.createInBackground(file);
  });
}
