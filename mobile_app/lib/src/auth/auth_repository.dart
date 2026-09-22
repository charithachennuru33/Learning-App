import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'models.dart';
import 'token_store.dart';

/// platform-infra authentication endpoints. Every method throws [ApiException] on failure.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Dio get _dio => _api.dio;

  Future<bool> hasSession() async => await _tokens.refreshToken() != null;

  Future<OtpChallenge> requestOtp(String phone) => _call(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/otp/request',
          data: {'phone': phone},
          options: ApiClient.anonymous,
        );
        return OtpChallenge.fromJson(res.data!['data'] as Map<String, dynamic>);
      });

  Future<void> verifyOtp(String phone, String otp) => _call(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/otp/verify',
          data: {'phone': phone, 'otp': otp},
          options: ApiClient.anonymous,
        );
        await _tokens.save(AuthTokens.fromJson(res.data!['data'] as Map<String, dynamic>));
      });

  Future<AppUser> me() => _call(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
        return AppUser.fromJson(res.data!['data'] as Map<String, dynamic>);
      });

  /// Ends the session on the server when possible; always clears local tokens.
  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post<void>(
          '/api/v1/auth/logout',
          data: {'refreshToken': refreshToken},
          options: ApiClient.anonymous,
        );
      }
    } on DioException {
      // Offline or server error: the refresh token expires on its own; don't block sign-out.
    } finally {
      await _tokens.clear();
    }
  }

  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
