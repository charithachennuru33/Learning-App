import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/src/api/api_client.dart';
import 'package:learning_app/src/api/api_exception.dart';
import 'package:learning_app/src/auth/auth_repository.dart';
import 'package:learning_app/src/auth/models.dart';
import 'package:learning_app/src/auth/token_store.dart';

import 'support/fake_server.dart';

void main() {
  late MemoryTokenStore store;
  late FakeServer server;
  late ApiClient api;
  late AuthRepository repo;
  late int expiredCalls;

  const me = {'id': 'u1', 'phone': '+919876543210', 'status': 'ACTIVE'};

  setUp(() {
    store = MemoryTokenStore(const AuthTokens(accessToken: 'old-access', refreshToken: 'refresh-1'));
    server = FakeServer((_) async => const FakeResponse(404, null));
    expiredCalls = 0;
    api = ApiClient(
      baseUrl: 'http://test',
      tokens: store,
      adapter: server,
      onSessionExpired: () => expiredCalls++,
    );
    repo = AuthRepository(api, store);
  });

  test('sends the stored access token', () async {
    server.handler = (_) async => FakeResponse(200, ok(me));
    final user = await repo.me();
    expect(user.phone, '+919876543210');
    expect(server.requests.single.authorization, 'Bearer old-access');
  });

  test('refreshes once on 401 and retries with the new token', () async {
    server.handler = (r) async {
      if (r.path == ApiClient.refreshPath) return FakeResponse(200, ok(tokens('new-access', 'refresh-2')));
      return r.authorization == 'Bearer new-access'
          ? FakeResponse(200, ok(me))
          : FakeResponse(401, failure('UNAUTHORIZED', 'Authentication required'));
    };

    await repo.me();

    expect(server.requests.map((r) => r.path),
        ['/api/v1/users/me', ApiClient.refreshPath, '/api/v1/users/me']);
    expect(server.requests[1].body, {'refreshToken': 'refresh-1'});
    expect(await store.refreshToken(), 'refresh-2');
    expect(expiredCalls, 0);
  });

  test('concurrent 401s share a single refresh', () async {
    server.handler = (r) async {
      if (r.path == ApiClient.refreshPath) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return FakeResponse(200, ok(tokens('new-access', 'refresh-2')));
      }
      return r.authorization == 'Bearer new-access'
          ? FakeResponse(200, ok(me))
          : FakeResponse(401, failure('UNAUTHORIZED', 'Authentication required'));
    };

    await Future.wait([repo.me(), repo.me(), repo.me()]);

    expect(server.requests.where((r) => r.path == ApiClient.refreshPath), hasLength(1));
  });

  test('rejected refresh token signs the user out', () async {
    server.handler = (r) async => r.path == ApiClient.refreshPath
        ? FakeResponse(401, failure('INVALID_REFRESH_TOKEN', 'Invalid or expired refresh token'))
        : FakeResponse(401, failure('UNAUTHORIZED', 'Authentication required'));

    await expectLater(repo.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(await store.refreshToken(), isNull);
    expect(expiredCalls, 1);
  });

  test('network failure during refresh keeps the session', () async {
    server.handler = (r) async {
      if (r.path == ApiClient.refreshPath) throw Exception('offline');
      return FakeResponse(401, failure('UNAUTHORIZED', 'Authentication required'));
    };

    await expectLater(repo.me(), throwsA(isA<ApiException>()));
    expect(await store.refreshToken(), 'refresh-1');
    expect(expiredCalls, 0);
  });

  test('parses error codes, field errors and Retry-After', () async {
    server.handler = (_) async => const FakeResponse(
          429,
          {
            'success': false,
            'message': 'Please wait before requesting another OTP',
            'error': {'code': 'OTP_RESEND_TOO_SOON', 'fields': {'phone': 'bad'}},
          },
          headers: {'retry-after': '42'},
        );

    final error = await repo.requestOtp('9876543210').then<ApiException?>((_) => null,
        onError: (Object e) => e as ApiException);

    expect(error!.code, 'OTP_RESEND_TOO_SOON');
    expect(error.message, 'Please wait before requesting another OTP');
    expect(error.retryAfter, const Duration(seconds: 42));
    expect(error.fields['phone'], 'bad');
    expect(server.requests.single.authorization, isNull, reason: 'OTP request is anonymous');
  });

  test('logout clears local tokens even when the server is unreachable', () async {
    server.handler = (_) async => throw Exception('offline');
    await repo.logout();
    expect(await store.refreshToken(), isNull);
  });
}
