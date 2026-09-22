import 'package:flutter/widgets.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'demo/demo_state.dart';
import 'theme/app_colors.dart';

/// Makes app-wide services available to screens: `AppScope.of(context).auth`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.repository,
    required this.demo,
    required this.theme,
    this.demoMode = false,
    required super.child,
  });

  final AuthController auth;
  final AuthRepository repository;

  /// Local catalogue, subscription and admin data backing the screens.
  final DemoState demo;

  /// Light (default) or dark; toggled from the button at the top of the screens.
  final ThemeController theme;

  /// True when talking to the in-app demo backend (fixed OTP) instead of platform-infra.
  final bool demoMode;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth ||
      repository != oldWidget.repository ||
      demo != oldWidget.demo ||
      theme != oldWidget.theme ||
      demoMode != oldWidget.demoMode;
}
