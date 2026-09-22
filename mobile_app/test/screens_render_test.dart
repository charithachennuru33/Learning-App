import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/app_scope.dart';
import 'package:learning_app/src/auth/auth_controller.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/models.dart';
import 'package:learning_app/src/auth/token_store.dart';
import 'package:learning_app/src/demo/demo_backend.dart';
import 'package:learning_app/src/demo/demo_state.dart';
import 'package:learning_app/src/features/admin/screens/admin_pricing_screen.dart';
import 'package:learning_app/src/features/admin/screens/admin_upload_screen.dart';
import 'package:learning_app/src/features/billing/screens/paywall_screen.dart';
import 'package:learning_app/src/features/catalog/screens/course_detail_screen.dart';
import 'package:learning_app/src/features/catalog/screens/domain_screen.dart';
import 'package:learning_app/src/features/catalog/screens/domains_screen.dart';
import 'package:learning_app/src/features/home/screens/home_screen.dart';
import 'package:learning_app/src/features/learning/screens/my_learning_screen.dart';
import 'package:learning_app/src/features/player/screens/player_screen.dart';
import 'package:learning_app/src/features/profile/screens/profile_screen.dart';
import 'package:learning_app/src/theme/app_colors.dart';
import 'package:learning_app/src/theme/app_theme.dart';

/// Renders every screen at the reference sizes and fails on any layout overflow.
void main() {
  const phone = Size(390, 844);
  const desktop = Size(1280, 900);

  Future<void> render(WidgetTester tester, Widget screen, Size size, {DemoState? demo}) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryTokenStore(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    final api = ApiClient(baseUrl: 'http://demo', tokens: store, adapter: DemoBackend(latency: Duration.zero));
    final repo = AuthRepository(api, store);
    final state = demo ?? DemoState();
    addTearDown(state.dispose);
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => screen)]);
    addTearDown(router.dispose);
    await tester.pumpWidget(AppScope(
      auth: AuthController(repo),
      repository: repo,
      demo: state,
      theme: ThemeController(),
      demoMode: true,
      child: MaterialApp.router(theme: buildAppTheme(AppColors.palette), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  }

  final phoneScreens = <String, Widget>{
    'home': const HomeScreen(),
    'domains': const DomainsScreen(),
    'domain': const DomainScreen(domainId: 'engineering'),
    'course (locked)': const CourseDetailScreen(courseId: 'signals'),
    'course (free)': const CourseDetailScreen(courseId: 'probability'),
    'player': const PlayerScreen(courseId: 'signals', lessonNumber: 2),
    'paywall': const PaywallScreen(),
    'profile': const ProfileScreen(),
    'my learning': const MyLearningScreen(),
    'admin upload (phone)': const AdminUploadScreen(),
    'admin pricing (phone)': const AdminPricingScreen(),
  };

  for (final entry in phoneScreens.entries) {
    testWidgets('${entry.key} renders at 390x844', (tester) => render(tester, entry.value, phone));
  }

  testWidgets('profile with an active plan renders', (tester) async {
    final demo = DemoState()..subscribe(DemoState().plans.firstWhere((p) => p.id == 'annual'));
    await render(tester, const ProfileScreen(), phone, demo: demo);
    expect(find.text('Premium · 12 months'), findsOneWidget);
  });

  testWidgets('admin upload renders at 1280x900 with sidebar', (tester) async {
    await render(tester, const AdminUploadScreen(), desktop);
    expect(find.text('PIPELINE QUEUE'), findsOneWidget);
    expect(find.text('Ram Intellect LLP'), findsOneWidget);
  });

  testWidgets('admin pricing renders at 1280x900 and edits flow to the paywall data', (tester) async {
    final demo = DemoState();
    await render(tester, const AdminPricingScreen(), desktop, demo: demo);
    expect(find.text('SUBSCRIPTION PLANS'), findsOneWidget);
    expect(find.text('LAUNCH40'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('couponCode')), 'DIWALI25');
    await tester.enterText(find.byKey(const Key('couponValue')), '25');
    await tester.enterText(find.byKey(const Key('couponMax')), '500');
    await tester.ensureVisible(find.byKey(const Key('createCoupon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createCoupon')));
    await tester.pump();
    expect(demo.findCoupon('diwali25'), isNotNull);
    expect(find.text('DIWALI25'), findsNWidgets(2)); // new table row + the field's example hint
  });

  testWidgets('admin upload queues a lesson and the pipeline advances it', (tester) async {
    final demo = DemoState();
    await render(tester, const AdminUploadScreen(), desktop, demo: demo);
    await tester.enterText(find.byKey(const Key('lessonTitle')), 'Z-transform, part one');
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pump();
    expect(demo.jobs.first.lessonTitle, 'Z-transform, part one');
    await tester.pump(const Duration(seconds: 2));
    expect(demo.jobs.first.progress, greaterThan(0));

    // Leaving the screen stops the simulated pipeline timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
