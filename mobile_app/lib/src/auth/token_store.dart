import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

abstract class TokenStore {
  Future<String?> accessToken();
  Future<String?> refreshToken();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

/// Keeps tokens in the iOS Keychain / Android Keystore-backed storage, with an
/// in-memory cache so every request doesn't hit the platform channel.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Readable after the first unlock (background refresh), never synced to other devices.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;
  bool _loaded = false;
  String? _access;
  String? _refresh;

  Future<void> _load() async {
    if (_loaded) return;
    _access = await _storage.read(key: _accessKey);
    _refresh = await _storage.read(key: _refreshKey);
    _loaded = true;
  }

  @override
  Future<String?> accessToken() async {
    await _load();
    return _access;
  }

  @override
  Future<String?> refreshToken() async {
    await _load();
    return _refresh;
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    _access = tokens.accessToken;
    _refresh = tokens.refreshToken;
    _loaded = true;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Non-persistent store for tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([AuthTokens? initial])
      : _access = initial?.accessToken,
        _refresh = initial?.refreshToken;

  String? _access;
  String? _refresh;

  @override
  Future<String?> accessToken() async => _access;

  @override
  Future<String?> refreshToken() async => _refresh;

  @override
  Future<void> save(AuthTokens tokens) async {
    _access = tokens.accessToken;
    _refresh = tokens.refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
