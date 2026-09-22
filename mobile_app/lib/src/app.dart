import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_scope.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'demo/demo_state.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class LearningApp extends StatefulWidget {
  const LearningApp({
    super.key,
    required this.auth,
    required this.repository,
    this._demo,
    this._theme,
    this.demoMode = false,
  });

  final AuthController auth;
  final AuthRepository repository;
  final DemoState? _demo;
  final ThemeController? _theme;
  final bool demoMode;

  @override
  State<LearningApp> createState() => _LearningAppState();
}

class _LearningAppState extends State<LearningApp> {
  late final DemoState _demo = widget._demo ?? DemoState();
  late final ThemeController _theme = widget._theme ?? ThemeController();
  late final GoRouter _router = buildRouter(widget.auth);

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _theme.addListener(_onThemeChanged);
  }

  // Signing out clears the learner's demo data (subscription, progress, bookmarks).
  void _onAuthChanged() {
    if (widget.auth.status == AuthStatus.signedOut) _demo.reset();
  }

  // Screens read colours from AppColors, so every element is rebuilt (keeping its state) after a switch.
  void _onThemeChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _theme.removeListener(_onThemeChanged);
    _router.dispose();
    if (widget._demo == null) _demo.dispose();
    if (widget._theme == null) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: widget.auth,
      repository: widget.repository,
      demo: _demo,
      theme: _theme,
      demoMode: widget.demoMode,
      child: MaterialApp.router(
        title: 'Ram Intellect',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(AppColors.palette),
        routerConfig: _router,
        builder: (context, child) => widget.demoMode
            ? Banner(
                message: 'DEMO',
                location: BannerLocation.topEnd,
                color: AppColors.purple,
                child: child!,
              )
            : child!,
      ),
    );
  }
}
