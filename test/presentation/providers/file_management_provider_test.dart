import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/data/services/file_storage_service.dart';
import 'package:repertoire_coach/presentation/providers/file_management_provider.dart';

import 'file_management_provider_test.mocks.dart';

@GenerateMocks([FileStorageService, FilePicker])
void main() {
  group('File Management Providers', () {
    test('fileStorageServiceProvider returns FileStorageService', () {
      final container = ProviderContainer();
      expect(container.read(fileStorageServiceProvider), isA<FileStorageService>());
    });

    test('fileImportControlsProvider returns FileImportControls', () {
      final container = ProviderContainer();
      expect(container.read(fileImportControlsProvider), isA<FileImportControls>());
    });

    group('FileImportControls', () {
      late MockFileStorageService mockFileStorageService;
      late MockFilePicker mockFilePicker;
      late ProviderContainer container;

      setUp(() {
        mockFileStorageService = MockFileStorageService();
        mockFilePicker = MockFilePicker();
        container = ProviderContainer(
          overrides: [
            fileStorageServiceProvider.overrideWithValue(mockFileStorageService),
            filePickerPlatformProvider.overrideWithValue(mockFilePicker),
          ],
        );
      });

      tearDown(() {
        container.dispose();
      });

      test('pickAndImportAudioFile returns path on success', () async {
        final platformFile = PlatformFile(name: 'audio.mp3', path: '/path/to/audio.mp3', size: 100);
        final filePickerResult = FilePickerResult([platformFile]);

        when(mockFilePicker.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        )).thenAnswer((_) async => filePickerResult);

        when(mockFileStorageService.importAudioFile('/path/to/audio.mp3'))
            .thenAnswer((_) async => '/app/storage/audio.mp3');

        final fileImportControls = container.read(fileImportControlsProvider);
        final result = await fileImportControls.pickAndImportAudioFile();

        expect(result, '/app/storage/audio.mp3');
        verify(mockFileStorageService.importAudioFile('/path/to/audio.mp3')).called(1);
      });

      test('pickAndImportAudioFile returns null if cancelled', () async {
        when(mockFilePicker.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        )).thenAnswer((_) async => null);

        final fileImportControls = container.read(fileImportControlsProvider);
        final result = await fileImportControls.pickAndImportAudioFile();

        expect(result, isNull);
        verifyNever(mockFileStorageService.importAudioFile(any));
      });

      test('pickAndImportAudioFile throws exception if file path is null', () async {
        final platformFile = PlatformFile(name: 'audio.mp3', path: null, size: 100);
        final filePickerResult = FilePickerResult([platformFile]);

        when(mockFilePicker.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        )).thenAnswer((_) async => filePickerResult);

        final fileImportControls = container.read(fileImportControlsProvider);
        expect(() => fileImportControls.pickAndImportAudioFile(), throwsException);
        verifyNever(mockFileStorageService.importAudioFile(any));
      });

      test('deleteAudioFile returns true on successful deletion', () async {
        when(mockFileStorageService.deleteAudioFile('/app/storage/audio.mp3'))
            .thenAnswer((_) async => true);

        final fileImportControls = container.read(fileImportControlsProvider);
        final result = await fileImportControls.deleteAudioFile('/app/storage/audio.mp3');

        expect(result, isTrue);
        verify(mockFileStorageService.deleteAudioFile('/app/storage/audio.mp3')).called(1);
      });

      test('deleteAudioFile returns false if file does not exist', () async {
        when(mockFileStorageService.deleteAudioFile('/app/storage/audio.mp3'))
            .thenAnswer((_) async => false);

        final fileImportControls = container.read(fileImportControlsProvider);
        final result = await fileImportControls.deleteAudioFile('/app/storage/audio.mp3');

        expect(result, isFalse);
        verify(mockFileStorageService.deleteAudioFile('/app/storage/audio.mp3')).called(1);
      });
    });
  });
}
