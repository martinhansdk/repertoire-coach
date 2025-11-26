import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for managing audio file storage in the app's local directory
class FileStorageService {
  static const String _audioDirectory = 'audio_files';
  final Uuid _uuid = const Uuid();

  /// Get the audio files directory, creating it if it doesn't exist
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(path.join(appDir.path, _audioDirectory));

    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    return audioDir;
  }

  /// Copy a file to app storage and return the new file path
  ///
  /// [sourcePath] - Path to the source file to copy
  /// Returns the absolute path to the copied file in app storage
  Future<String> importAudioFile(String sourcePath) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    // Get file extension
    final extension = path.extension(sourcePath);

    // Generate unique filename
    final uniqueId = _uuid.v4();
    final fileName = '$uniqueId$extension';

    // Get destination directory
    final audioDir = await _getAudioDirectory();
    final destinationPath = path.join(audioDir.path, fileName);

    // Copy file
    final destinationFile = await sourceFile.copy(destinationPath);

    return destinationFile.path;
  }

  /// Delete an audio file from app storage
  ///
  /// [filePath] - Absolute path to the file to delete
  /// Returns true if the file was deleted, false if it didn't exist
  Future<bool> deleteAudioFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return false;
    }

    await file.delete();
    return true;
  }

  /// Check if a file exists in app storage
  ///
  /// [filePath] - Absolute path to check
  /// Returns true if the file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Get the total size of all audio files in bytes
  Future<int> getTotalStorageUsed() async {
    final audioDir = await _getAudioDirectory();

    if (!await audioDir.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in audioDir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }

    return totalSize;
  }

  /// Delete all audio files in app storage
  ///
  /// Returns the number of files deleted
  Future<int> clearAllAudioFiles() async {
    final audioDir = await _getAudioDirectory();

    if (!await audioDir.exists()) {
      return 0;
    }

    int deletedCount = 0;
    await for (final entity in audioDir.list()) {
      if (entity is File) {
        await entity.delete();
        deletedCount++;
      }
    }

    return deletedCount;
  }
}
