import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'features/admin/screens/admin_pricing_screen.dart';
import 'features/admin/screens/admin_upload_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/billing/screens/paywall_screen.dart';
import 'features/catalog/screens/course_detail_screen.dart';
import 'features/catalog/screens/domain_screen.dart';
import 'features/catalog/screens/domains_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/learning/screens/my_learning_screen.dart';
import 'features/player/screens/player_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'widgets/app_shell.dart';
import 'widgets/splash_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const domains = '/domains';
  static const learning = '/learning';
  static const profile = '/profile';
  static const paywall = '/paywall';
  static const adminUpload = '/admin/upload';
  static const adminPricing = '/admin/pricing';

  static String domain(String id) => '/domain/$id';
  static String course(String id) => '/course/$id';
  static String player(String courseId, int lesson) => '/player/$courseId/$lesson';
}

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.unknown:
          return path == Routes.splash ? null : Routes.splash;
        case AuthStatus.signedOut:
          return path == Routes.login ? null : Routes.login;
        case AuthStatus.signedIn:
          return (path == Routes.login || path == Routes.splash) ? Routes.home : null;
      }
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),

      // The four bottom-bar tabs keep their own navigation state.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.domains, builder: (_, _) => const DomainsScreen())]),
          StatefulShellBranch(
              routes: [GoRoute(path: Routes.learning, builder: (_, _) => const MyLearningScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())]),
        ],
      ),

      // Full-screen pages above the tabs.
      GoRoute(
        path: '/domain/:id',
        builder: (_, state) => DomainScreen(domainId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/course/:id',
        builder: (_, state) => CourseDetailScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:course/:lesson',
        builder: (_, state) => PlayerScreen(
          courseId: state.pathParameters['course']!,
          lessonNumber: int.parse(state.pathParameters['lesson']!),
        ),
      ),
      GoRoute(
        path: Routes.paywall,
        pageBuilder: (_, _) => const MaterialPage(fullscreenDialog: true, child: PaywallScreen()),
      ),
      GoRoute(path: Routes.adminUpload, builder: (_, _) => const AdminUploadScreen()),
      GoRoute(path: Routes.adminPricing, builder: (_, _) => const AdminPricingScreen()),
    ],
  );
}
