import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Build-time configuration. Pass values with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.demoMode = false});

  final String apiBaseUrl;

  /// Uses the in-app demo backend (OTP 123456) instead of platform-infra. Never enabled in release builds.
  final bool demoMode;

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  // On by default in debug builds until the backend runs locally; pass DEMO_MODE=false to use it.
  static const _demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  factory AppConfig.fromEnvironment() {
    final demo = _demoMode && !kReleaseMode;
    if (_apiBaseUrl.isNotEmpty) return AppConfig(apiBaseUrl: _apiBaseUrl, demoMode: demo);
    if (kReleaseMode) {
      throw StateError('Release builds need --dart-define=API_BASE_URL=https://...');
    }
    // Local development against platform-infra on this PC. The Android emulator
    // reaches the host machine through 10.0.2.2; the iOS simulator shares its network.
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return AppConfig(apiBaseUrl: 'http://$host:8080', demoMode: demo);
  }
}
