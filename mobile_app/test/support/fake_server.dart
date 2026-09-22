import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A request the fake server received.
class RecordedRequest {
  RecordedRequest(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? body;

  String? get authorization => headers['Authorization'] as String?;
}

class FakeResponse {
  const FakeResponse(this.status, this.body, {this.headers = const {}});

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

typedef FakeHandler = Future<FakeResponse> Function(RecordedRequest request);

/// In-process stand-in for platform-infra, plugged into Dio as its HTTP adapter.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);

  FakeHandler handler;
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = RecordedRequest(options.method, options.path, Map.of(options.headers), options.data);
    requests.add(request);
    final response = await handler(request);
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in response.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> ok(Object? data) => {'success': true, 'data': data};

Map<String, dynamic> failure(String code, String message) => {
      'success': false,
      'message': message,
      'error': {'code': code},
    };

Map<String, dynamic> tokens(String access, String refresh) => {
      'userId': '00000000-0000-0000-0000-000000000001',
      'tokenType': 'Bearer',
      'accessToken': access,
      'accessTokenExpiresAt': '2030-01-01T00:00:00Z',
      'expiresIn': 900,
      'refreshToken': refresh,
      'refreshTokenExpiresAt': '2030-01-30T00:00:00Z',
    };
