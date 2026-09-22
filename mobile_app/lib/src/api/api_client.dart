import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/models.dart';
import '../auth/token_store.dart';

/// HTTP client for platform-infra. Adds the access token to requests and, on a 401,
/// rotates the refresh token once and retries. Concurrent 401s share one refresh:
/// the server treats reuse of a rotated refresh token as theft and ends the session.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this._tokens,
    this.onSessionExpired,
    HttpClientAdapter? adapter,
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    dio = Dio(options);
    _refreshDio = Dio(options);
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _refreshDio.httpClientAdapter = adapter;
    }
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  /// Marks a request as not needing (or not accepting) an access token.
  static Options get anonymous => Options(extra: {_authKey: false});

  static const _authKey = 'auth';
  static const _retriedKey = 'auth.retried';
  static const refreshPath = '/api/v1/auth/token/refresh';

  final TokenStore _tokens;

  /// Called when the refresh token is rejected; the user must sign in again.
  void Function()? onSessionExpired;

  late final Dio dio;
  late final Dio _refreshDio;
  Future<String?>? _refreshing;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[_authKey] != false) {
      final token = await _tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final eligible = err.response?.statusCode == 401 &&
        request.extra[_authKey] != false &&
        request.extra[_retriedKey] != true;
    if (!eligible) return handler.next(err);

    final String? newToken;
    try {
      newToken = await _refreshAccessToken();
    } on DioException {
      // Network trouble during refresh: keep the session, surface the original error.
      return handler.next(err);
    }
    if (newToken == null) return handler.next(err);

    try {
      request.extra[_retriedKey] = true;
      request.headers['Authorization'] = 'Bearer $newToken';
      handler.resolve(await dio.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Returns a fresh access token, or null if the session is over.
  Future<String?> _refreshAccessToken() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refreshToken = await _tokens.refreshToken();
    if (refreshToken == null) {
      await _expireSession();
      return null;
    }
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!['data'] as Map<String, dynamic>);
      await _tokens.save(tokens);
      return tokens.accessToken;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await _expireSession();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _expireSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }
}
