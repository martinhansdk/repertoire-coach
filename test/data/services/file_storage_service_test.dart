import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/services/file_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileStorageService', () {
    late FileStorageService service;
    late Directory tempDir;

    setUp(() {
      service = FileStorageService();
    });

    tearDown(() async {
      // Clean up any created directories
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('importAudioFile should copy file to app storage', () async {
      // Arrange: Create a temporary source file
      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsString('test audio content');

      // Act
      final importedPath = await service.importAudioFile(sourceFile.path);

      // Assert
      expect(importedPath, isNotEmpty);
      final importedFile = File(importedPath);
      expect(await importedFile.exists(), isTrue);

      final content = await importedFile.readAsString();
      expect(content, 'test audio content');

      // Verify file extension is preserved
      expect(importedPath.endsWith('.mp3'), isTrue);

      // Clean up imported file
      await importedFile.delete();
    }, skip: 'Requires path_provider platform implementation');

    test('importAudioFile should generate unique filenames', () async {
      // Arrange: Create a temporary source file
      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsString('test content');

      // Act: Import the same file twice
      final importedPath1 = await service.importAudioFile(sourceFile.path);
      final importedPath2 = await service.importAudioFile(sourceFile.path);

      // Assert: Paths should be different
      expect(importedPath1, isNot(equals(importedPath2)));

      // Both files should exist
      expect(await File(importedPath1).exists(), isTrue);
      expect(await File(importedPath2).exists(), isTrue);

      // Clean up
      await File(importedPath1).delete();
      await File(importedPath2).delete();
    }, skip: 'Requires path_provider platform implementation');

    test('importAudioFile should throw when source file does not exist', () async {
      // Arrange: Non-existent file path
      const nonExistentPath = '/path/to/nonexistent/file.mp3';

      // Act & Assert
      expect(
        () => service.importAudioFile(nonExistentPath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('importAudioFile should preserve file extension', () async {
      // Arrange: Create files with different extensions
      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      final extensions = ['.mp3', '.wav', '.m4a', '.ogg'];

      for (final ext in extensions) {
        final sourceFile = File('${tempDir.path}/source$ext');
        await sourceFile.writeAsString('test content');

        // Act
        final importedPath = await service.importAudioFile(sourceFile.path);

        // Assert
        expect(importedPath.endsWith(ext), isTrue);

        // Clean up
        await File(importedPath).delete();
      }
    }, skip: 'Requires path_provider platform implementation');

    test('deleteAudioFile should delete existing file', () async {
      // Arrange: Create and import a file
      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsString('test content');
      final importedPath = await service.importAudioFile(sourceFile.path);

      // Verify file exists before deletion
      expect(await File(importedPath).exists(), isTrue);

      // Act
      final deleted = await service.deleteAudioFile(importedPath);

      // Assert
      expect(deleted, isTrue);
      expect(await File(importedPath).exists(), isFalse);
    }, skip: 'Requires path_provider platform implementation');

    test('deleteAudioFile should return false for non-existent file', () async {
      // Arrange: Non-existent file path
      const nonExistentPath = '/path/to/nonexistent/file.mp3';

      // Act
      final deleted = await service.deleteAudioFile(nonExistentPath);

      // Assert
      expect(deleted, isFalse);
    });

    test('fileExists should return true for existing file', () async {
      // Arrange: Create and import a file
      tempDir = await Directory.systemTemp.createTemp('test_audio_');
      final sourceFile = File('${tempDir.path}/source.mp3');
      await sourceFile.writeAsString('test content');
      final importedPath = await service.importAudioFile(sourceFile.path);

      // Act
      final exists = await service.fileExists(importedPath);

      // Assert
      expect(exists, isTrue);

      // Clean up
      await File(importedPath).delete();
    }, skip: 'Requires path_provider platform implementation');

    test('fileExists should return false for non-existent file', () async {
      // Arrange: Non-existent file path
      const nonExistentPath = '/path/to/nonexistent/file.mp3';

      // Act
      final exists = await service.fileExists(nonExistentPath);

      // Assert
      expect(exists, isFalse);
    });

    test('getTotalStorageUsed should calculate total size correctly', () async {
      // Arrange: Create and import multiple files
      tempDir = await Directory.systemTemp.createTemp('test_audio_');

      final sourceFile1 = File('${tempDir.path}/source1.mp3');
      await sourceFile1.writeAsString('a' * 100); // 100 bytes

      final sourceFile2 = File('${tempDir.path}/source2.mp3');
      await sourceFile2.writeAsString('b' * 200); // 200 bytes

      final importedPath1 = await service.importAudioFile(sourceFile1.path);
      final importedPath2 = await service.importAudioFile(sourceFile2.path);

      // Act
      final totalSize = await service.getTotalStorageUsed();

      // Assert
      expect(totalSize, greaterThanOrEqualTo(300)); // At least 300 bytes

      // Clean up
      await File(importedPath1).delete();
      await File(importedPath2).delete();
    }, skip: 'Requires path_provider platform implementation');

    test('clearAllAudioFiles should delete all audio files', () async {
      // Arrange: Create and import multiple files
      tempDir = await Directory.systemTemp.createTemp('test_audio_');

      final sourceFile1 = File('${tempDir.path}/source1.mp3');
      await sourceFile1.writeAsString('test1');

      final sourceFile2 = File('${tempDir.path}/source2.mp3');
      await sourceFile2.writeAsString('test2');

      final importedPath1 = await service.importAudioFile(sourceFile1.path);
      final importedPath2 = await service.importAudioFile(sourceFile2.path);

      // Verify files exist before clearing
      expect(await File(importedPath1).exists(), isTrue);
      expect(await File(importedPath2).exists(), isTrue);

      // Act
      final deletedCount = await service.clearAllAudioFiles();

      // Assert
      expect(deletedCount, greaterThanOrEqualTo(2));
      expect(await File(importedPath1).exists(), isFalse);
      expect(await File(importedPath2).exists(), isFalse);
    }, skip: 'Requires path_provider platform implementation');

    test('clearAllAudioFiles should return 0 when no files exist', () async {
      // Arrange: Ensure no files exist
      await service.clearAllAudioFiles();

      // Act
      final deletedCount = await service.clearAllAudioFiles();

      // Assert
      expect(deletedCount, 0);
    }, skip: 'Requires path_provider platform implementation');
  });
}
