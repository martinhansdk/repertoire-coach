import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'r2_signer_client.dart';

/// Result of an audio file upload
class AudioUploadResult {
  /// Canonical object key in the R2 bucket (use as [storagePath]).
  final String storagePath;

  /// Duration of the audio file in milliseconds (if available)
  final int? durationMs;

  const AudioUploadResult({
    required this.storagePath,
    this.durationMs,
  });
}

/// Service for uploading and managing audio files in R2 storage.
///
/// Upload flow:
///   1. Requests a presigned PUT URL from the audio-signer Edge Function.
///   2. Uploads bytes directly to R2 via HTTP PUT.
///   3. Returns the canonical object key as [storagePath].
///
/// Handles both mobile (file path) and web (bytes) uploads.
class AudioStorageService {
  final R2SignerClient _signerClient;
  final http.Client _http;

  AudioStorageService(this._signerClient, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Upload an audio file from a local file path (mobile/desktop).
  ///
  /// Throws [ArgumentError] on web — use [uploadAudioFromBytes] instead.
  Future<AudioUploadResult> uploadAudioFromFile({
    required String filePath,
    required String choirId,
    required String trackId,
  }) async {
    if (kIsWeb) {
      throw ArgumentError(
        'uploadAudioFromFile cannot be used on web. Use uploadAudioFromBytes instead.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final extension = path.extension(path.basename(filePath)).toLowerCase();

    return _uploadAudio(
      bytes: bytes,
      choirId: choirId,
      trackId: trackId,
      extension: extension,
      contentType: _contentTypeForExtension(extension),
    );
  }

  /// Upload an audio file from bytes (web/mobile).
  ///
  /// Throws [ArgumentError] if [fileName] has no extension.
  Future<AudioUploadResult> uploadAudioFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String choirId,
    required String trackId,
  }) async {
    final extension = path.extension(fileName).toLowerCase();
    if (extension.isEmpty) {
      throw ArgumentError(
        'fileName must have a valid extension (e.g., .mp3, .m4a)',
        'fileName',
      );
    }

    return _uploadAudio(
      bytes: bytes,
      choirId: choirId,
      trackId: trackId,
      extension: extension,
      contentType: _contentTypeForExtension(extension),
    );
  }

  Future<AudioUploadResult> _uploadAudio({
    required Uint8List bytes,
    required String choirId,
    required String trackId,
    required String extension,
    required String contentType,
  }) async {
    // 1. Get presigned PUT URL from the signer
    final target = await _signerClient.getUploadUrl(
      choirId: choirId,
      trackId: trackId,
      extension: extension,
      contentType: contentType,
    );

    // 2. PUT bytes directly to R2
    final uploadResponse = await _http.put(
      Uri.parse(target.uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception(
        'R2 upload failed: HTTP ${uploadResponse.statusCode}',
      );
    }

    return AudioUploadResult(
      storagePath: target.objectKey,
      // TODO: Extract audio duration (requires audio processing package)
      durationMs: null,
    );
  }

  /// Delete an audio file from R2.
  ///
  /// [storagePath]: The object key returned from upload.
  /// [trackId]: The track ID (used for authorization).
  Future<void> deleteAudio(String storagePath, String trackId) async {
    await _signerClient.deleteObject(storagePath, trackId);
  }

  static String _contentTypeForExtension(String extension) {
    switch (extension) {
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/x-m4a';
      case '.mp4':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.aac':
        return 'audio/aac';
      case '.flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }
}
