import 'package:flutter/material.dart';

import 'src/api/api_client.dart';
import 'src/app.dart';
import 'src/auth/auth_controller.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/token_store.dart';
import 'src/config/app_config.dart';
import 'src/demo/demo_backend.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  // Demo sessions live only in memory, like the demo backend, so a restart starts signed out.
  final TokenStore tokens = config.demoMode ? MemoryTokenStore() : SecureTokenStore();
  final api = ApiClient(
    baseUrl: config.apiBaseUrl,
    tokens: tokens,
    adapter: config.demoMode ? DemoBackend() : null,
  );
  final repository = AuthRepository(api, tokens);
  final auth = AuthController(repository);
  api.onSessionExpired = auth.sessionExpired;
  auth.init();

  runApp(LearningApp(auth: auth, repository: repository, demoMode: config.demoMode));
}
