import 'package:dio/dio.dart';

/// A failed API call, carrying platform-infra's stable `error.code`
/// (e.g. `INVALID_OTP`, `OTP_RESEND_TOO_SOON`) so the UI can react to it.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.retryAfter,
    this.fields = const {},
  });

  static const networkError = 'NETWORK_ERROR';

  final String code;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;

  /// Per-field validation messages, keyed by request field name.
  final Map<String, String> fields;

  bool get isNetworkError => code == networkError;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        code: networkError,
        message: 'Could not reach the server. Check your connection and try again.',
      );
    }

    var code = 'HTTP_${response.statusCode}';
    var message = 'Something went wrong. Please try again.';
    final fields = <String, String>{};

    final data = response.data;
    if (data is Map) {
      if (data['message'] is String) message = data['message'] as String;
      final error = data['error'];
      if (error is Map) {
        if (error['code'] is String) code = error['code'] as String;
        final rawFields = error['fields'];
        if (rawFields is Map) {
          rawFields.forEach((k, v) => fields['$k'] = '$v');
        }
      }
    }

    final retrySeconds = int.tryParse(response.headers.value('retry-after') ?? '');
    return ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
      fields: fields,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
