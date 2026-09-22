import 'package:flutter/foundation.dart';

import 'auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// App-wide sign-in state. The router listens to it to guard screens.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  AuthStatus _status = AuthStatus.unknown;

  AuthStatus get status => _status;

  /// Restores a stored session. Works offline: the token is only checked on the next API call.
  Future<void> init() async {
    _set(await _repository.hasSession() ? AuthStatus.signedIn : AuthStatus.signedOut);
  }

  Future<void> verifyOtp(String phone, String otp) async {
    await _repository.verifyOtp(phone, otp);
    _set(AuthStatus.signedIn);
  }

  Future<void> logout() async {
    await _repository.logout();
    _set(AuthStatus.signedOut);
  }

  /// Called by the API client when the server rejects the refresh token.
  void sessionExpired() => _set(AuthStatus.signedOut);

  void _set(AuthStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }
}
