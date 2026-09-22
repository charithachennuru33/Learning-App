class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  /// Parses the `data` object of `/otp/verify` and `/token/refresh` responses.
  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class OtpChallenge {
  const OtpChallenge({required this.expiresIn, required this.resendAfter});

  final Duration expiresIn;
  final Duration resendAfter;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        expiresIn: Duration(seconds: (json['expiresInSeconds'] as num).toInt()),
        resendAfter: Duration(seconds: (json['resendAfterSeconds'] as num).toInt()),
      );
}

class AppUser {
  const AppUser({required this.id, required this.phone, required this.status});

  final String id;
  final String? phone;
  final String status;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        status: json['status'] as String,
      );
}
