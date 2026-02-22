import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:repertoire_coach/core/services/r2_signer_client.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds an [R2SignerClient] wired to [token] and the given [http.Client].
/// Uses [R2SignerClient.withTokenGetter] to avoid mocking the Supabase chain.
R2SignerClient _makeClient({
  required String? token,
  required http.Client httpClient,
}) =>
    R2SignerClient.withTokenGetter(
      getToken: () => token,
      httpClient: httpClient,
    );

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('R2SignerClient', () {
    group('getPlayUrl', () {
      test('returns URL from 200 response', () async {
        final r2 = _makeClient(
          token: 'tok123',
          httpClient: _mockHttp(
            (_) => _jsonResponse({'url': 'https://r2.example.com/play'}),
          ),
        );

        final url = await r2.getPlayUrl('track-1');
        expect(url, 'https://r2.example.com/play');
      });

      test('sends Authorization header with Bearer token', () async {
        String? capturedAuth;
        final r2 = _makeClient(
          token: 'my-token',
          httpClient: _mockHttp((req) {
            capturedAuth = req.headers['authorization'];
            return _jsonResponse({'url': 'https://r2.example.com/play'});
          }),
        );

        await r2.getPlayUrl('track-1');
        expect(capturedAuth, 'Bearer my-token');
      });

      test('sends Content-Type application/json', () async {
        String? capturedContentType;
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((req) {
            capturedContentType = req.headers['content-type'];
            return _jsonResponse({'url': 'https://r2.example.com/play'});
          }),
        );

        await r2.getPlayUrl('track-1');
        expect(capturedContentType, contains('application/json'));
      });

      test('sends trackId in request body', () async {
        Map<String, dynamic>? capturedBody;
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((req) {
            capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
            return _jsonResponse({'url': 'https://r2.example.com/play'});
          }),
        );

        await r2.getPlayUrl('my-track-id');
        expect(capturedBody, containsPair('trackId', 'my-track-id'));
      });

      test('throws R2SignerException(401) when token is null (no session)', () {
        final r2 = _makeClient(
          token: null,
          httpClient: _mockHttp((_) => _jsonResponse({'url': 'never'})),
        );

        expect(
          () => r2.getPlayUrl('track-1'),
          throwsA(
            isA<R2SignerException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.message, 'message', 'No active session'),
          ),
        );
      });

      test('throws R2SignerException on 401 response', () async {
        final r2 = _makeClient(
          token: 'expired-token',
          httpClient: _mockHttp(
            (_) => _jsonResponse({'error': 'Unauthorized'}, status: 401),
          ),
        );

        await expectLater(
          r2.getPlayUrl('track-1'),
          throwsA(
            isA<R2SignerException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.message, 'message', 'Unauthorized'),
          ),
        );
      });

      test('throws R2SignerException on 403 response', () async {
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp(
            (_) => _jsonResponse({'error': 'Forbidden'}, status: 403),
          ),
        );

        await expectLater(
          r2.getPlayUrl('track-1'),
          throwsA(
            isA<R2SignerException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.message, 'message', 'Forbidden'),
          ),
        );
      });

      test('throws R2SignerException on 404 response', () async {
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp(
            (_) => _jsonResponse({'error': 'Not found'}, status: 404),
          ),
        );

        await expectLater(
          r2.getPlayUrl('track-1'),
          throwsA(
            isA<R2SignerException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.message, 'message', 'Not found'),
          ),
        );
      });

      test('uses generic message when error field missing in non-200 response',
          () async {
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((_) => _jsonResponse({}, status: 500)),
        );

        await expectLater(
          r2.getPlayUrl('track-1'),
          throwsA(
            isA<R2SignerException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.message, 'message', 'Request failed'),
          ),
        );
      });
    });

    group('getUploadUrl', () {
      test('returns R2UploadTarget from 200 response', () async {
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((_) => _jsonResponse({
                'url': 'https://r2.example.com/upload',
                'objectKey': 'choirs/c1/tracks/t1.mp3',
              })),
        );

        final target = await r2.getUploadUrl(
          choirId: 'c1',
          trackId: 't1',
          extension: '.mp3',
          contentType: 'audio/mpeg',
        );

        expect(target.uploadUrl, 'https://r2.example.com/upload');
        expect(target.objectKey, 'choirs/c1/tracks/t1.mp3');
      });

      test('sends all required fields in request body', () async {
        Map<String, dynamic>? body;
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((req) {
            body = jsonDecode(req.body) as Map<String, dynamic>;
            return _jsonResponse({'url': 'u', 'objectKey': 'k'});
          }),
        );

        await r2.getUploadUrl(
          choirId: 'choir-1',
          trackId: 'track-1',
          extension: '.m4a',
          contentType: 'audio/x-m4a',
        );

        expect(body, containsPair('choirId', 'choir-1'));
        expect(body, containsPair('trackId', 'track-1'));
        expect(body, containsPair('extension', '.m4a'));
        expect(body, containsPair('contentType', 'audio/x-m4a'));
      });

      test('throws R2SignerException(401) when no session', () {
        final r2 = _makeClient(
          token: null,
          httpClient:
              _mockHttp((_) => _jsonResponse({'url': 'u', 'objectKey': 'k'})),
        );

        expect(
          () => r2.getUploadUrl(
            choirId: 'c',
            trackId: 't',
            extension: '.mp3',
            contentType: 'audio/mpeg',
          ),
          throwsA(isA<R2SignerException>()
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
      });
    });

    group('deleteObject', () {
      test('completes successfully on 200 response', () async {
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((_) => _jsonResponse({'ok': true})),
        );

        await expectLater(
          r2.deleteObject('choirs/c1/tracks/t1.mp3', 'track-1'),
          completes,
        );
      });

      test('sends storagePath and trackId in request body', () async {
        Map<String, dynamic>? body;
        final r2 = _makeClient(
          token: 'tok',
          httpClient: _mockHttp((req) {
            body = jsonDecode(req.body) as Map<String, dynamic>;
            return _jsonResponse({'ok': true});
          }),
        );

        await r2.deleteObject('choirs/c1/tracks/t1.mp3', 'track-1');

        expect(body, containsPair('storagePath', 'choirs/c1/tracks/t1.mp3'));
        expect(body, containsPair('trackId', 'track-1'));
      });

      test('throws R2SignerException(401) when no session', () {
        final r2 = _makeClient(
          token: null,
          httpClient: _mockHttp((_) => _jsonResponse({'ok': true})),
        );

        expect(
          () => r2.deleteObject('path', 'track-1'),
          throwsA(isA<R2SignerException>()
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Mock HTTP client — lightweight handler-based fake, no code generation needed
// ---------------------------------------------------------------------------

http.Client _mockHttp(http.Response Function(http.Request) handler) =>
    _FakeHttpClient(handler);

class _FakeHttpClient extends http.BaseClient {
  final http.Response Function(http.Request) _handler;
  _FakeHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final response = _handler(req);
    return http.StreamedResponse(
      Stream.value(Uint8List.fromList(response.bodyBytes)),
      response.statusCode,
      headers: response.headers,
    );
  }
}
