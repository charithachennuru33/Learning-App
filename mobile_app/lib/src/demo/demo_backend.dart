import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// In-app stand-in for platform-infra's auth API, used when the app runs in demo mode.
/// It follows the real server's rules and response shapes, so the app code is unchanged:
/// the OTP is always [demoOtp], 5 wrong guesses burn the code, and resends wait [resendCooldown].
class DemoBackend implements HttpClientAdapter {
  DemoBackend({this.latency = const Duration(milliseconds: 400)});

  static const demoOtp = '123456';
  static const resendCooldown = Duration(seconds: 30);
  static const _maxAttempts = 5;

  final Duration latency;
  final _random = Random.secure();

  final _pendingOtp = <String, int>{}; // phone -> wrong attempts so far
  final _lastSent = <String, DateTime>{};
  final _users = <String, String>{}; // phone -> user id
  final _accessTokens = <String, String>{}; // token -> phone
  final _refreshTokens = <String, String>{}; // token -> phone

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(latency);
    final body = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : const <String, dynamic>{};
    final bearer = (options.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');

    return switch ((options.method, options.path)) {
      ('POST', '/api/v1/auth/otp/request') => _requestOtp(body),
      ('POST', '/api/v1/auth/otp/verify') => _verify(body),
      ('POST', '/api/v1/auth/token/refresh') => _refresh(body),
      ('POST', '/api/v1/auth/logout') => _logout(body),
      ('GET', '/api/v1/users/me') => _me(bearer),
      _ => _error(404, 'NOT_FOUND', 'Resource not found'),
    };
  }

  ResponseBody _requestOtp(Map<String, dynamic> body) {
    final phone = _normalize(body['phone'] as String?);
    if (phone == null) return _error(400, 'INVALID_PHONE_NUMBER', 'Invalid phone number');

    final last = _lastSent[phone];
    if (last != null) {
      final wait = resendCooldown - DateTime.now().difference(last);
      if (!wait.isNegative) {
        return _error(429, 'OTP_RESEND_TOO_SOON', 'Please wait before requesting another OTP',
            retryAfter: wait.inSeconds + 1);
      }
    }
    _lastSent[phone] = DateTime.now();
    _pendingOtp[phone] = 0;
    return _ok({'expiresInSeconds': 300, 'resendAfterSeconds': resendCooldown.inSeconds}, 'OTP sent');
  }

  ResponseBody _verify(Map<String, dynamic> body) {
    final phone = _normalize(body['phone'] as String?);
    final attempts = phone == null ? null : _pendingOtp[phone];
    if (phone == null || attempts == null) return _error(401, 'INVALID_OTP', 'Invalid or expired OTP');

    if (body['otp'] == demoOtp) {
      _pendingOtp.remove(phone);
      _users.putIfAbsent(phone, _uuid);
      return _ok(_issueTokens(phone), 'Authenticated');
    }
    if (attempts + 1 >= _maxAttempts) {
      _pendingOtp.remove(phone);
      return _error(429, 'OTP_ATTEMPTS_EXCEEDED', 'Too many incorrect attempts. Request a new OTP');
    }
    _pendingOtp[phone] = attempts + 1;
    return _error(401, 'INVALID_OTP', 'Invalid or expired OTP');
  }

  ResponseBody _refresh(Map<String, dynamic> body) {
    final phone = _refreshTokens.remove(body['refreshToken']);
    if (phone == null) return _error(401, 'INVALID_REFRESH_TOKEN', 'Invalid or expired refresh token');
    return _ok(_issueTokens(phone), null);
  }

  ResponseBody _logout(Map<String, dynamic> body) {
    final phone = _refreshTokens.remove(body['refreshToken']);
    if (phone != null) _accessTokens.removeWhere((_, p) => p == phone);
    return ResponseBody.fromString('', 204);
  }

  ResponseBody _me(String? bearer) {
    final phone = bearer == null ? null : _accessTokens[bearer];
    if (phone == null) return _error(401, 'UNAUTHORIZED', 'Authentication required');
    return _ok({'id': _users[phone], 'phone': phone, 'email': null, 'status': 'ACTIVE'}, null);
  }

  Map<String, dynamic> _issueTokens(String phone) {
    final access = 'demo-access-${_token()}';
    final refresh = 'demo-refresh-${_token()}';
    _accessTokens[access] = phone;
    _refreshTokens[refresh] = phone;
    final now = DateTime.now().toUtc();
    return {
      'userId': _users[phone],
      'tokenType': 'Bearer',
      'accessToken': access,
      'accessTokenExpiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
      'expiresIn': 900,
      'refreshToken': refresh,
      'refreshTokenExpiresAt': now.add(const Duration(days: 30)).toIso8601String(),
    };
  }

  /// Rough stand-in for the server's libphonenumber check: 10-digit Indian mobile or +countrycode.
  static String? _normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+')) return digits.length >= 8 && digits.length <= 15 ? '+$digits' : null;
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    if (local.length == 10 && RegExp(r'^[6-9]').hasMatch(local)) return '+91$local';
    if (local.length == 12 && local.startsWith('91')) return '+$local';
    return null;
  }

  String _token() => base64Url.encode(List.generate(24, (_) => _random.nextInt(256))).replaceAll('=', '');

  String _uuid() {
    final b = List.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static ResponseBody _ok(Object? data, String? message) => _json(200, {
        'success': true,
        'data': data,
        'message': ?message,
      });

  static ResponseBody _error(int status, String code, String message, {int? retryAfter}) => _json(
        status,
        {'success': false, 'message': message, 'error': {'code': code}},
        headers: {if (retryAfter != null) 'retry-after': ['$retryAfter']},
      );

  static ResponseBody _json(int status, Object body, {Map<String, List<String>> headers = const {}}) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      });

  @override
  void close({bool force = false}) {}
}
