import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';
import '../config/environment.dart';

/// Result of a successful upload sign request.
class R2UploadTarget {
  /// Presigned PUT URL to upload bytes directly to R2.
  final String uploadUrl;

  /// Canonical object key in the R2 bucket (use this as [storagePath]).
  final String objectKey;

  const R2UploadTarget({required this.uploadUrl, required this.objectKey});
}

/// Client for the `audio-signer` Supabase Edge Function.
///
/// Handles all interactions with R2-backed audio: obtaining presigned URLs for
/// playback and upload, and requesting server-side deletes.
///
/// Requires the caller to be authenticated — calls will throw [R2SignerException]
/// with status 401 if the session has expired.
class R2SignerClient {
  final SupabaseService _supabaseService;
  final http.Client _http;

  static String get _baseUrl =>
      '${Environment.supabaseUrl}/functions/v1/audio-signer';

  R2SignerClient(this._supabaseService, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Returns a short-lived presigned GET URL for playing [trackId].
  Future<String> getPlayUrl(String trackId) async {
    final result = await _post('play', {'trackId': trackId});
    return result['url'] as String;
  }

  /// Returns a presigned PUT URL and the canonical object key for a new upload.
  Future<R2UploadTarget> getUploadUrl({
    required String choirId,
    required String trackId,
    required String extension,
    required String contentType,
  }) async {
    final result = await _post('upload', {
      'choirId': choirId,
      'trackId': trackId,
      'extension': extension,
      'contentType': contentType,
    });
    return R2UploadTarget(
      uploadUrl: result['url'] as String,
      objectKey: result['objectKey'] as String,
    );
  }

  /// Deletes the R2 object at [storagePath] associated with [trackId].
  Future<void> deleteObject(String storagePath, String trackId) async {
    await _post('delete', {'storagePath': storagePath, 'trackId': trackId});
  }

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, String> body,
  ) async {
    final token = _supabaseService.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const R2SignerException('No active session', statusCode: 401);
    }

    final response = await _http.post(
      Uri.parse('$_baseUrl/$action'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw R2SignerException(
        json['error'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }

    return json;
  }
}

class R2SignerException implements Exception {
  final String message;
  final int statusCode;

  const R2SignerException(this.message, {required this.statusCode});

  @override
  String toString() => 'R2SignerException($statusCode): $message';
}
