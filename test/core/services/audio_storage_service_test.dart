import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/core/services/audio_storage_service.dart';
import 'package:repertoire_coach/core/services/r2_signer_client.dart';

import 'audio_storage_service_test.mocks.dart';

@GenerateMocks([R2SignerClient])
void main() {
  group('AudioStorageService', () {
    late MockR2SignerClient mockSigner;
    late AudioStorageService service;

    setUp(() {
      mockSigner = MockR2SignerClient();
      service = AudioStorageService(mockSigner);
    });

    // -----------------------------------------------------------------------
    // uploadAudioFromBytes
    // -----------------------------------------------------------------------

    group('uploadAudioFromBytes', () {
      const fakeTarget = R2UploadTarget(
        uploadUrl: 'https://r2.example.com/presigned-put',
        objectKey: 'choirs/c1/tracks/t1.mp3',
      );
      final fakeBytes = Uint8List.fromList([1, 2, 3]);

      test('returns AudioUploadResult with storagePath from signer', () async {
        when(mockSigner.getUploadUrl(
          choirId: anyNamed('choirId'),
          trackId: anyNamed('trackId'),
          extension: anyNamed('extension'),
          contentType: anyNamed('contentType'),
        )).thenAnswer((_) async => fakeTarget);

        final service200 = AudioStorageService(
          mockSigner,
          httpClient: _fakeHttp(statusCode: 200),
        );

        final result = await service200.uploadAudioFromBytes(
          bytes: fakeBytes,
          fileName: 'song.mp3',
          choirId: 'c1',
          trackId: 't1',
        );

        expect(result.storagePath, 'choirs/c1/tracks/t1.mp3');
      });

      test('passes correct extension and contentType to signer for .mp3',
          () async {
        String? capturedExtension;
        String? capturedContentType;

        when(mockSigner.getUploadUrl(
          choirId: anyNamed('choirId'),
          trackId: anyNamed('trackId'),
          extension: anyNamed('extension'),
          contentType: anyNamed('contentType'),
        )).thenAnswer((inv) async {
          capturedExtension = inv.namedArguments[#extension] as String;
          capturedContentType = inv.namedArguments[#contentType] as String;
          return fakeTarget;
        });

        final service200 = AudioStorageService(
          mockSigner,
          httpClient: _fakeHttp(statusCode: 200),
        );

        await service200.uploadAudioFromBytes(
          bytes: fakeBytes,
          fileName: 'track.mp3',
          choirId: 'c1',
          trackId: 't1',
        );

        expect(capturedExtension, '.mp3');
        expect(capturedContentType, 'audio/mpeg');
      });

      test('passes correct contentType for .m4a', () async {
        String? capturedContentType;
        when(mockSigner.getUploadUrl(
          choirId: anyNamed('choirId'),
          trackId: anyNamed('trackId'),
          extension: anyNamed('extension'),
          contentType: anyNamed('contentType'),
        )).thenAnswer((inv) async {
          capturedContentType = inv.namedArguments[#contentType] as String;
          return fakeTarget;
        });

        final service200 = AudioStorageService(
          mockSigner,
          httpClient: _fakeHttp(statusCode: 200),
        );

        await service200.uploadAudioFromBytes(
          bytes: fakeBytes,
          fileName: 'track.m4a',
          choirId: 'c1',
          trackId: 't1',
        );

        expect(capturedContentType, 'audio/x-m4a');
      });

      test('throws ArgumentError when fileName has no extension', () {
        expect(
          () => service.uploadAudioFromBytes(
            bytes: fakeBytes,
            fileName: 'no-extension',
            choirId: 'c1',
            trackId: 't1',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws Exception when R2 PUT returns non-200', () async {
        when(mockSigner.getUploadUrl(
          choirId: anyNamed('choirId'),
          trackId: anyNamed('trackId'),
          extension: anyNamed('extension'),
          contentType: anyNamed('contentType'),
        )).thenAnswer((_) async => fakeTarget);

        final serviceFail = AudioStorageService(
          mockSigner,
          httpClient: _fakeHttp(statusCode: 403),
        );

        await expectLater(
          serviceFail.uploadAudioFromBytes(
            bytes: fakeBytes,
            fileName: 'track.mp3',
            choirId: 'c1',
            trackId: 't1',
          ),
          throwsException,
        );
      });
    });

    // -----------------------------------------------------------------------
    // uploadAudioFromFile
    // -----------------------------------------------------------------------

    group('uploadAudioFromFile', () {
      late Directory tempDir;
      late File tempFile;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('audio_storage_test_');
        tempFile = File('${tempDir.path}/track.mp3');
        await tempFile.writeAsBytes([0xAA, 0xBB, 0xCC]);
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      test('returns AudioUploadResult when file exists and PUT succeeds',
          () async {
        const target = R2UploadTarget(
          uploadUrl: 'https://r2.example.com/upload',
          objectKey: 'choirs/c1/tracks/t1.mp3',
        );

        when(mockSigner.getUploadUrl(
          choirId: anyNamed('choirId'),
          trackId: anyNamed('trackId'),
          extension: anyNamed('extension'),
          contentType: anyNamed('contentType'),
        )).thenAnswer((_) async => target);

        final service200 = AudioStorageService(
          mockSigner,
          httpClient: _fakeHttp(statusCode: 200),
        );

        final result = await service200.uploadAudioFromFile(
          filePath: tempFile.path,
          choirId: 'c1',
          trackId: 't1',
        );

        expect(result.storagePath, 'choirs/c1/tracks/t1.mp3');
      });

      test('throws FileSystemException when file does not exist', () {
        expect(
          () => service.uploadAudioFromFile(
            filePath: '/nonexistent/path/track.mp3',
            choirId: 'c1',
            trackId: 't1',
          ),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // deleteAudio
    // -----------------------------------------------------------------------

    group('deleteAudio', () {
      test('delegates to signerClient.deleteObject', () async {
        when(mockSigner.deleteObject(any, any)).thenAnswer((_) async {});

        await service.deleteAudio('choirs/c1/tracks/t1.mp3', 'track-1');

        verify(mockSigner.deleteObject(
          'choirs/c1/tracks/t1.mp3',
          'track-1',
        )).called(1);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal HTTP client that returns a fixed status code
// ---------------------------------------------------------------------------

http.Client _fakeHttp({required int statusCode}) =>
    _FixedStatusHttpClient(statusCode: statusCode);

class _FixedStatusHttpClient extends http.BaseClient {
  final int _statusCode;
  _FixedStatusHttpClient({required int statusCode}) : _statusCode = statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(Uint8List(0)),
      _statusCode,
    );
  }
}
