import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_service.dart';

/// Result of an audio file upload
class AudioUploadResult {
  /// Public URL to access the audio file
  final String audioUrl;

  /// Path in Supabase Storage bucket
  final String storagePath;

  /// Duration of the audio file in milliseconds (if available)
  final int? durationMs;

  const AudioUploadResult({
    required this.audioUrl,
    required this.storagePath,
    this.durationMs,
  });
}

/// Service for uploading and managing audio files in Supabase Storage
///
/// Handles both mobile (file path) and web (bytes) uploads.
/// Audio files are organized by choir and track ID:
/// `audio/{choirId}/{trackId}.{extension}`
class AudioStorageService {
  static const String _bucketName = 'audio';

  final SupabaseService _supabaseService;

  AudioStorageService(this._supabaseService);

  /// Upload an audio file to Supabase Storage from a file path (mobile/desktop)
  ///
  /// [filePath]: Local file path to the audio file
  /// [choirId]: ID of the choir this track belongs to
  /// [trackId]: ID of the track
  ///
  /// Returns [AudioUploadResult] with the public URL and storage path
  ///
  /// Throws:
  /// - [ArgumentError] if called on web platform (use [uploadAudioFromBytes] instead)
  /// - [FileSystemException] if file doesn't exist or can't be read
  /// - [Exception] if upload fails
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

    // Read file
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final fileName = path.basename(filePath);
    final extension = path.extension(fileName).toLowerCase();

    return _uploadAudio(
      bytes: bytes,
      choirId: choirId,
      trackId: trackId,
      extension: extension,
    );
  }

  /// Upload an audio file to Supabase Storage from bytes (web/mobile)
  ///
  /// [bytes]: Audio file data
  /// [fileName]: Original file name (used to determine extension)
  /// [choirId]: ID of the choir this track belongs to
  /// [trackId]: ID of the track
  ///
  /// Returns [AudioUploadResult] with the public URL and storage path
  ///
  /// Throws:
  /// - [ArgumentError] if fileName has no extension
  /// - [Exception] if upload fails
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
    );
  }

  /// Internal method to upload audio bytes to Supabase Storage
  Future<AudioUploadResult> _uploadAudio({
    required Uint8List bytes,
    required String choirId,
    required String trackId,
    required String extension,
  }) async {
    // Build storage path: audio/{choirId}/{trackId}.{extension}
    final storagePath = 'audio/$choirId/$trackId$extension';

    try {
      // Upload to Supabase Storage
      await _supabaseService.client.storage
          .from(_bucketName)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true, // Allow overwriting if track is edited
            ),
          );

      // Get public URL
      final audioUrl = _supabaseService.client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return AudioUploadResult(
        audioUrl: audioUrl,
        storagePath: storagePath,
        // TODO: Extract audio duration (requires audio processing package)
        durationMs: null,
      );
    } catch (e) {
      throw Exception('Failed to upload audio file: $e');
    }
  }

  /// Delete an audio file from Supabase Storage
  ///
  /// [storagePath]: The storage path returned from upload (e.g., "audio/choir-id/track-id.mp3")
  ///
  /// Throws [Exception] if deletion fails
  Future<void> deleteAudio(String storagePath) async {
    try {
      await _supabaseService.client.storage
          .from(_bucketName)
          .remove([storagePath]);
    } catch (e) {
      throw Exception('Failed to delete audio file: $e');
    }
  }

  /// Check if an audio file exists in Supabase Storage
  ///
  /// [storagePath]: The storage path to check
  ///
  /// Returns true if the file exists, false otherwise
  Future<bool> audioExists(String storagePath) async {
    try {
      final files = await _supabaseService.client.storage
          .from(_bucketName)
          .list(path: path.dirname(storagePath));

      final fileName = path.basename(storagePath);
      return files.any((file) => file.name == fileName);
    } catch (e) {
      return false;
    }
  }
}
