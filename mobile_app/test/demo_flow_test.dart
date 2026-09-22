import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/app.dart';
import 'package:learning_app/src/auth/auth_controller.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/token_store.dart';
import 'package:learning_app/src/demo/demo_backend.dart';
import 'package:learning_app/src/demo/demo_state.dart';
import 'package:learning_app/src/theme/app_colors.dart';

void main() {
  late AuthController auth;
  late AuthRepository repo;
  late DemoState demo;

  setUp(() {
    final store = MemoryTokenStore();
    final api = ApiClient(baseUrl: 'http://demo', tokens: store, adapter: DemoBackend(latency: Duration.zero));
    repo = AuthRepository(api, store);
    auth = AuthController(repo);
    api.onSessionExpired = auth.sessionExpired;
    demo = DemoState();
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(LearningApp(auth: auth, repository: repo, demo: demo, demoMode: true));
    await auth.init();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demoNotice')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
    await tester.tap(find.byKey(const Key('sendCodeButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otpField')), DemoBackend.demoOtp);
    await tester.pumpAndSettle();
    expect(auth.status, AuthStatus.signedIn);
  }

  testWidgets('demo code signs in and lands on Home', (tester) async {
    await signIn(tester);
    expect(find.text('CONTINUE WATCHING'), findsOneWidget);
    expect(find.text("Bayes' theorem in practice"), findsOneWidget);
    expect(find.byKey(const Key('premiumBanner')), findsOneWidget);
    expect(find.text('Trending in Engineering'), findsOneWidget);
  });

  testWidgets('locked lesson -> paywall -> coupon -> subscribe unlocks content', (tester) async {
    await signIn(tester);

    // Open a course and tap a premium lesson.
    await tester.tap(find.text('Signals & Systems from scratch').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unlockAll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lesson-3')));
    await tester.pumpAndSettle();
    expect(find.text('Every domain,\none subscription'), findsOneWidget);

    // Invalid, then valid coupon.
    await tester.scrollUntilVisible(find.byKey(const Key('couponField')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('couponField')), 'NOPE');
    await tester.tap(find.byKey(const Key('applyCoupon')));
    await tester.pump();
    expect(find.text('That code isn’t valid.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('couponField')), 'launch40');
    await tester.tap(find.byKey(const Key('applyCoupon')));
    await tester.pump();
    expect(find.text('LAUNCH40 applied · 40% off'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('plan-monthly')));
    await tester.tap(find.byKey(const Key('plan-monthly')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('paywallContinue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(demo.isPremium, isTrue);
    expect(demo.activePlan!.id, 'monthly');
    // Back on the course: the unlock bar is gone and lesson 3 plays.
    expect(find.byKey(const Key('unlockAll')), findsNothing);
    await tester.tap(find.byKey(const Key('lesson-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playPause')), findsOneWidget);
  });

  testWidgets('player saves progress and Home resumes it', (tester) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('continueWatching')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playPause')));
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byKey(const Key('playPause'))); // pause saves progress
    await tester.pump();
    final saved = demo.progressOf('probability', 6);
    expect(saved, greaterThan(0.62));

    await tester.tap(find.byTooltip('Close player'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE WATCHING'), findsOneWidget);
  });

  testWidgets('starts in the white theme and the top toggle switches to dark and back', (tester) async {
    final theme = ThemeController();
    await tester.pumpWidget(LearningApp(auth: auth, repository: repo, demo: demo, theme: theme, demoMode: true));
    await auth.init();
    await tester.pumpAndSettle();

    Color background() => tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(theme.isDark, isFalse);
    expect(background(), Colors.white);

    await tester.tap(find.byKey(const Key('themeToggle')));
    await tester.pumpAndSettle();
    expect(theme.isDark, isTrue);
    expect(background(), AppPalette.dark.ink);

    // Typed text survives the switch (elements are rebuilt, not replaced).
    await tester.enterText(find.byKey(const Key('phoneField')), '98765');
    await tester.tap(find.byKey(const Key('themeToggle')));
    await tester.pumpAndSettle();
    expect(background(), Colors.white);
    expect(find.text('98765'), findsOneWidget);
  });

  testWidgets('signing out clears the subscription', (tester) async {
    await signIn(tester);
    demo.subscribe(demo.visiblePlans.last);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('premiumCard')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('signOut')));
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    expect(auth.status, AuthStatus.signedOut);
    expect(demo.isPremium, isFalse);
  });
}
