// Scripted walkthrough of every screen, used to record the demo video:
//
//   flutter test integration_test/demo_tour_test.dart -d <device>
//
// while `adb shell screenrecord` captures the screen (see tool/record_demo.ps1). Captions at the bottom name
// each step. Everything runs on the in-app demo data; no backend is involved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/app.dart';
import 'package:learning_app/src/auth/auth_controller.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/token_store.dart';
import 'package:learning_app/src/demo/demo_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('demo tour', (tester) async {
    final caption = ValueNotifier('');
    final store = MemoryTokenStore();
    final api = ApiClient(baseUrl: 'http://demo', tokens: store, adapter: DemoBackend());
    final repo = AuthRepository(api, store);
    final auth = AuthController(repo);
    api.onSessionExpired = auth.sessionExpired;

    await tester.pumpWidget(_Captioned(
      caption: caption,
      child: LearningApp(auth: auth, repository: repo, demoMode: true),
    ));
    await auth.init();

    // Real-time pause so viewers can follow; keeps frames flowing.
    Future<void> hold([int ms = 1800]) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Waits for animations to finish; screens that animate continuously (the admin pipeline) never
    // settle, so give up after a couple of seconds and carry on.
    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 2));
      } on FlutterError {
        // still animating: fine for a recording
      }
    }

    Future<void> step(String text, [int ms = 1400]) async {
      caption.value = text;
      await hold(ms);
    }

    Future<void> tap(Finder finder, {int after = 1200}) async {
      await tester.ensureVisible(finder);
      await settle();
      await tester.tap(finder);
      await settle();
      await hold(after);
    }

    // Types like a person rather than pasting.
    Future<void> type(Finder field, String text) async {
      await tester.ensureVisible(field);
      await tester.tap(field);
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(field, text.substring(0, i));
        await hold(90);
      }
      await settle();
    }

    // Android system back.
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await settle();
      await hold(700);
    }

    Future<void> scroll(Finder scrollable, double by) async {
      await tester.drag(scrollable, Offset(0, -by));
      await settle();
      await hold(900);
    }

    // The recorder starts when the app process appears; this pause covers the gap.
    debugPrint('DEMO_TOUR_START');
    await settle();
    await hold(5000);

    // --- Login -------------------------------------------------------------------------------------------
    await step('Login · phone number, no password', 2200);
    await type(find.byKey(const Key('phoneField')), '9876543210');
    await tap(find.byKey(const Key('sendCodeButton')), after: 1500);
    await step('Step 2 · enter the six-digit code (demo: 123456)', 1800);
    await type(find.byKey(const Key('otpField')), DemoBackend.demoOtp);
    await settle();

    // --- Home --------------------------------------------------------------------------------------------
    await step('Home · continue watching, domains, trending courses', 2600);
    await scroll(find.byType(Scrollable).first, 350);
    await hold(1200);
    await scroll(find.byType(Scrollable).first, -350);

    // --- Domains -----------------------------------------------------------------------------------------
    await tap(find.text('Domains'));
    await step('All domains · search and browse', 2000);
    await type(find.byKey(const Key('domainSearch')), 'sig');
    await hold(1500);
    await tester.enterText(find.byKey(const Key('domainSearch')), '');
    await settle();
    await tap(find.text('Engineering'), after: 1800);
    await step('Domain · every course in Engineering', 1800);

    // --- Course detail -----------------------------------------------------------------------------------
    await tap(find.text('Signals & Systems from scratch'));
    await step('Course detail · free previews, locked premium lessons', 2600);
    await tap(find.text('About'), after: 1500);
    await tap(find.text('Lessons'), after: 800);

    // --- Player ------------------------------------------------------------------------------------------
    await tap(find.byKey(const Key('lesson-2')));
    await step('Player · resumes where you left off', 1500);
    await tap(find.byKey(const Key('playPause')), after: 3000);
    await step('Player · playback speed and quality', 1000);
    await tap(find.byKey(const Key('speedButton')), after: 800);
    await tap(find.byTooltip('Video quality (Auto)'), after: 1400);
    await tap(find.text('1080p'), after: 900);
    await step('Player · save offline, bookmark, up next', 1500);
    await tap(find.text('Save offline'), after: 1600);
    await tap(find.byKey(const Key('playPause')), after: 600);
    await back();

    // --- Paywall (first look) ----------------------------------------------------------------------------
    await tap(find.byKey(const Key('lesson-3')));
    await step('Paywall · locked lesson opens the plans', 2400);
    await back(); // paywall
    await back(); // course
    await back(); // domain

    // --- Admin panel -------------------------------------------------------------------------------------
    await tap(find.text('Profile'));
    await step('Profile · plan, learning, account', 2000);
    await tap(find.byKey(const Key('adminPanel')));
    await step('Admin · upload a lesson', 2000);
    await type(find.byKey(const Key('lessonTitle')), 'Z-transform, part one');
    await tap(find.byKey(const Key('chooseFile')), after: 800);
    await step('Admin · pipeline queue: uploading → transcoding → ready', 1200);
    await scroll(find.byType(Scrollable).first, 700);
    await hold(2600);
    await step('Admin · failed jobs stay visible and can be retried', 1000);
    await tap(find.text('Retry'), after: 2200);

    await tap(find.byTooltip('Open navigation menu'), after: 1200);
    await step('Admin · menu: videos, categories, pricing, coupons', 1200);
    await tap(find.text('Pricing').last);
    await step('Admin · pricing & coupons', 1800);
    await tap(find.text('₹[PRICE]').first, after: 600);
    await type(find.byKey(const Key('priceField')), '299');
    await tap(find.text('Save'), after: 1400);
    await step('Admin · set a price; the paywall picks it up', 1200);
    await scroll(find.byType(Scrollable).first, 600);
    await type(find.byKey(const Key('couponCode')), 'DIWALI25');
    await type(find.byKey(const Key('couponValue')), '25');
    await type(find.byKey(const Key('couponMax')), '500');
    await tap(find.byKey(const Key('createCoupon')), after: 1400);
    await step('Admin · new coupon created', 1400);
    await tap(find.text('Open the app'), after: 1000);

    // --- Paywall purchase --------------------------------------------------------------------------------
    await tap(find.byKey(const Key('premiumBanner')));
    await step('Paywall · plans with the admin price', 1600);
    await tap(find.byKey(const Key('plan-monthly')), after: 800);
    await type(find.byKey(const Key('couponField')), 'LAUNCH40');
    await tap(find.byKey(const Key('applyCoupon')), after: 1400);
    await step('Paywall · coupon applied', 1200);
    await tap(find.byKey(const Key('paywallContinue')), after: 1200);
    await tap(find.text('Activate'), after: 1600);
    await step('Premium active · every lesson unlocked', 2000);

    // --- My learning + Profile ---------------------------------------------------------------------------
    await tap(find.text('My learning'));
    await step('My learning · in progress and saved', 2200);
    await tap(find.text('Profile'));
    await step('Profile · active subscription', 2400);

    // --- Theme ---------------------------------------------------------------------------------------------
    await tap(find.text('Home'));
    await step('Theme · switch from the top', 1000);
    await tap(find.byKey(const Key('themeToggle')), after: 2400);
    await tap(find.text('Domains'), after: 1600);
    await tap(find.byKey(const Key('themeToggle')), after: 1400);

    // --- Sign out ------------------------------------------------------------------------------------------
    await tap(find.text('Profile'));
    await tap(find.byKey(const Key('signOut')), after: 1200);
    await step('Ram Intellect · demo build', 2500);
    caption.value = '';
    await hold(800);
    debugPrint('DEMO_TOUR_END');
  });
}

/// Draws a caption pill above the app for the recording.
class _Captioned extends StatelessWidget {
  const _Captioned({required this.caption, required this.child});

  final ValueNotifier<String> caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        child,
        ValueListenableBuilder<String>(
          valueListenable: caption,
          builder: (context, text, _) => text.isEmpty
              ? const SizedBox.shrink()
              : Positioned(
                  left: 20,
                  right: 20,
                  bottom: 110,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xE614151A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2F6BFF), width: 1.5),
                        ),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF4F3EF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
