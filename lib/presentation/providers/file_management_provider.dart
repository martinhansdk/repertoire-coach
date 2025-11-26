import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/file_storage_service.dart';

/// Provider for the file storage service
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

/// Helper methods for file import operations
///
/// These methods can be called from UI widgets to import and manage audio files.
class FileImportControls {
  final Ref _ref;

  FileImportControls(this._ref);

  FileStorageService get _fileStorageService =>
      _ref.read(fileStorageServiceProvider);

  /// Pick an audio file and import it to app storage
  ///
  /// Returns the path to the imported file, or null if cancelled
  Future<String?> pickAndImportAudioFile() async {
    try {
      // Use file_picker to select an audio file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        throw Exception('File path is null');
      }

      // Import the file to app storage
      final importedPath = await _fileStorageService.importAudioFile(file.path!);
      return importedPath;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an audio file from app storage
  Future<bool> deleteAudioFile(String filePath) async {
    return await _fileStorageService.deleteAudioFile(filePath);
  }
}

/// Provider for file import controls
///
/// Use this to pick and import audio files from the UI
/// Example: ref.read(fileImportControlsProvider).pickAndImportAudioFile()
final fileImportControlsProvider = Provider<FileImportControls>((ref) {
  return FileImportControls(ref);
});
