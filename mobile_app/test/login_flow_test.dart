import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/app.dart';
import 'package:learning_app/src/auth/auth_controller.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/token_store.dart';

import 'support/fake_server.dart';

void main() {
  testWidgets('phone -> OTP -> home -> profile -> sign out (real API contract)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = MemoryTokenStore();
    final server = FakeServer((r) async {
      switch (r.path) {
        case '/api/v1/auth/otp/request':
          return FakeResponse(200, ok({'expiresInSeconds': 300, 'resendAfterSeconds': 60}));
        case '/api/v1/auth/otp/verify':
          final body = r.body as Map;
          return body['otp'] == '123456'
              ? FakeResponse(200, ok(tokens('access', 'refresh')))
              : FakeResponse(401, failure('INVALID_OTP', 'Invalid or expired OTP'));
        case '/api/v1/users/me':
          return FakeResponse(200, ok({'id': 'u1', 'phone': '+919876543210', 'status': 'ACTIVE'}));
        case '/api/v1/auth/logout':
          return const FakeResponse(204, null);
      }
      return const FakeResponse(404, null);
    });
    final api = ApiClient(baseUrl: 'http://test', tokens: store, adapter: server);
    final repo = AuthRepository(api, store);
    final auth = AuthController(repo);
    api.onSessionExpired = auth.sessionExpired;

    await tester.pumpWidget(LearningApp(auth: auth, repository: repo));
    await auth.init();
    await tester.pumpAndSettle();

    // Step 1 with client-side validation.
    expect(find.text('Enter your number'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sendCodeButton')));
    await tester.pump();
    expect(find.text('Enter a valid mobile number'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('phoneField')), '98765 43210');
    await tester.tap(find.byKey(const Key('sendCodeButton')));
    await tester.pumpAndSettle();
    expect(server.requests.last.body, {'phone': '+91 98765 43210'});

    // Step 2 appears on the same screen.
    expect(find.text('STEP 2 · VERIFY'), findsOneWidget);
    expect(find.text('Code sent to +91 98765 43210'), findsOneWidget);
    expect(find.text('Resend in 1:00'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otpField')), '000000');
    await tester.pumpAndSettle();
    expect(find.text('That code is wrong or has expired.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otpField')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE WATCHING'), findsOneWidget);
    expect(await store.accessToken(), 'access');

    // Profile tab shows the number from /users/me.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('+91 98765 43210'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('signOut')));
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your number'), findsOneWidget);
    expect(await store.refreshToken(), isNull);
  });
}
