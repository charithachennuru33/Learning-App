import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/api/api_exception.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/token_store.dart';
import 'package:learning_app/src/demo/demo_backend.dart';

void main() {
  late MemoryTokenStore store;
  late AuthRepository repo;

  setUp(() {
    store = MemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'http://demo',
      tokens: store,
      adapter: DemoBackend(latency: Duration.zero),
    );
    repo = AuthRepository(api, store);
  });

  Future<ApiException> failure(Future<Object?> call) =>
      call.then<ApiException>((_) => fail('expected ApiException'), onError: (Object e) => e as ApiException);

  test('demo code signs in and the session works', () async {
    await repo.requestOtp('98765 43210');
    await repo.verifyOtp('9876543210', DemoBackend.demoOtp);

    final user = await repo.me();
    expect(user.phone, '+919876543210');

    await repo.logout();
    expect(await store.refreshToken(), isNull);
  });

  test('wrong codes are rejected and burn the code after 5 tries', () async {
    await repo.requestOtp('9876543210');
    for (var i = 0; i < 4; i++) {
      expect((await failure(repo.verifyOtp('9876543210', '000000'))).code, 'INVALID_OTP');
    }
    expect((await failure(repo.verifyOtp('9876543210', '000000'))).code, 'OTP_ATTEMPTS_EXCEEDED');
    expect((await failure(repo.verifyOtp('9876543210', DemoBackend.demoOtp))).code, 'INVALID_OTP');
  });

  test('resend is throttled and invalid numbers are rejected', () async {
    await repo.requestOtp('9876543210');
    final tooSoon = await failure(repo.requestOtp('9876543210'));
    expect(tooSoon.code, 'OTP_RESEND_TOO_SOON');
    expect(tooSoon.retryAfter, isNotNull);

    expect((await failure(repo.requestOtp('12345'))).code, 'INVALID_PHONE_NUMBER');
  });
}
