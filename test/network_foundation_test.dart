import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/interceptors/auth_interceptor.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';

SessionTokens credentials(
  String access,
  String refresh, {
  int seconds = 3600,
}) => SessionTokens(
  access,
  refresh,
  accessTokenExpiresAtUtc: DateTime.now().toUtc().add(
    Duration(seconds: seconds),
  ),
  refreshTokenExpiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 7)),
);

class MemoryTokens implements TokenStorage {
  SessionTokens? value;
  @override
  Future<SessionTokens?> readTokens() async => value;
  @override
  Future<void> writeTokens(SessionTokens tokens) async {
    value = tokens;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class TestAdapter implements HttpClientAdapter {
  int calls = 0;
  int? statusOverride;
  final requests = <RequestOptions>[];
  bool alwaysReject = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      statusOverride ??
          (!alwaysReject && options.headers['Authorization'] == 'Bearer new'
              ? 200
              : 401),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MemoryTokens storage;
  late SessionManager session;
  late Dio dio;
  late TestAdapter adapter;
  setUp(() async {
    storage = MemoryTokens();
    session = SessionManager(storage);
    await session.signIn(credentials('old', 'refresh'));
    adapter = TestAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
      ..httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close();
    await session.dispose();
  });

  test(
    'five near-expiry calls wait for one proactive refresh before transport',
    () async {
      await session.signIn(credentials('old', 'refresh', seconds: 30));
      final pending = Completer<SessionTokens>();
      var count = 0;
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) {
          count++;
          return pending.future;
        }),
      );
      final calls = List.generate(5, (_) => dio.get('/protected'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.calls, 0);
      expect(count, 1);
      pending.complete(credentials('new', 'rotated'));
      await Future.wait(calls);
      expect(adapter.calls, 5);
      expect(
        adapter.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer new',
        ),
        true,
      );
      expect(storage.value?.refreshToken, 'rotated');
      expect(storage.value?.accessTokenExpiresAtUtc, isNotNull);
    },
  );

  test(
    'concurrent proactive failure expires once and never sends originals',
    () async {
      await session.signIn(credentials('old', 'refresh', seconds: -1));
      final pending = Completer<SessionTokens>();
      var count = 0, expired = 0;
      final subscription = session.changes.listen((s) {
        if (s == SessionStatus.expired) expired++;
      });
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) {
          count++;
          return pending.future;
        }),
      );
      final calls = List.generate(
        5,
        (_) => expectLater(dio.get('/protected'), throwsA(isA<DioException>())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      pending.completeError(const FormatException('Refresh failed'));
      await Future.wait(calls);
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);
      expect(expired, 1);
      expect(adapter.calls, 0);
      expect(session.tokens, isNull);
      await subscription.cancel();
    },
  );

  test(
    'missing expired and unknown refresh credentials skip network',
    () async {
      for (final value in [
        credentials('old', '', seconds: 0),
        SessionTokens(
          'old',
          'r',
          accessTokenExpiresAtUtc: DateTime.utc(2000),
          refreshTokenExpiresAtUtc: DateTime.utc(2000),
        ),
        const SessionTokens('old', 'r'),
      ]) {
        await session.signIn(value);
        var count = 0;
        dio.interceptors.clear();
        dio.interceptors.add(
          AuthInterceptor(dio, session, (_) async {
            count++;
            return credentials('new', 'r');
          }),
        );
        await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
        expect(count, 0);
        expect(session.isAuthenticated, false);
      }
      expect(adapter.calls, 0);
    },
  );

  test(
    'valid access does not refresh; non-401 errors do not refresh',
    () async {
      var count = 0;
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) async {
          count++;
          return credentials('new', 'r');
        }),
      );
      adapter.statusOverride = 200;
      await dio.get('/protected');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer old');
      for (final code in [400, 403, 404, 500]) {
        adapter.statusOverride = code;
        await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      }
      expect(count, 0);
    },
  );

  test('retry preserves original request options', () async {
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async => credentials('new', 'rotated')),
    );
    await dio.post(
      '/protected',
      queryParameters: {'page': 3},
      data: {'value': 42},
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.plain,
        headers: {'X-Test': 'preserved'},
        extra: {'marker': true},
      ),
    );
    expect(adapter.calls, 2);
    final retry = adapter.requests.last;
    expect(retry.method, 'POST');
    expect(retry.path, '/protected');
    expect(retry.queryParameters, {'page': 3});
    expect(retry.data, {'value': 42});
    expect(retry.responseType, ResponseType.plain);
    expect(retry.contentType, Headers.jsonContentType);
    expect(retry.headers['X-Test'], 'preserved');
    expect(retry.extra['marker'], true);
    expect(retry.extra['authRetried'], true);
  });

  test(
    'subsequent refresh uses rotated refresh token and preserves user',
    () async {
      await session.signIn(
        credentials('old', 'OLD', seconds: 0),
        user: const SessionUser(id: '4098', name: 'Engineer'),
      );
      final used = <String>[];
      Future<SessionTokens> refresh(String token) async {
        used.add(token);
        return credentials('new', 'NEW');
      }

      await session.ensureFresh(refresh);
      await session.ensureFresh(refresh, force: true);
      expect(used, ['OLD', 'NEW']);
      expect(session.userId, 4098);
      expect(session.user?.name, 'Engineer');
    },
  );

  test('concurrent 401s refresh once and replay all requests', () async {
    var refreshes = 0;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return credentials('new', 'rotated');
      }),
    );
    final responses = await Future.wait(
      List.generate(6, (_) => dio.get('/protected')),
    );
    expect(responses.every((r) => r.statusCode == 200), true);
    expect(refreshes, 1);
    expect(storage.value?.refreshToken, 'rotated');
  });
  test('concurrent 401 refresh failure logs out only once', () async {
    var count = 0, expired = 0;
    final sub = session.changes.listen((status) {
      if (status == SessionStatus.expired) expired++;
    });
    final pending = Completer<SessionTokens>();
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) {
        count++;
        return pending.future;
      }),
    );
    final calls = List.generate(
      5,
      (_) => expectLater(dio.get('/protected'), throwsA(isA<DioException>())),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(count, 1);
    pending.completeError(const FormatException('Server failure'));
    await Future.wait(calls);
    await Future<void>.delayed(Duration.zero);
    expect(expired, 1);
    expect(count, 1);
    expect(session.tokens, isNull);
    await sub.cancel();
  });

  test(
    'late refresh from old login cannot overwrite or log out new login',
    () async {
      final pending = Completer<SessionTokens>();
      final started = Completer<void>();
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) {
          started.complete();
          return pending.future;
        }),
      );
      final request = expectLater(
        dio.get('/protected'),
        throwsA(isA<DioException>()),
      );
      await started.future;
      await session.logout();
      await session.signIn(
        credentials('other-access', 'other-refresh'),
        user: const SessionUser(id: '9'),
      );
      pending.complete(credentials('new', 'rotated'));
      await request;
      expect(session.isAuthenticated, true);
      expect(session.userId, 9);
      expect(session.tokens!.accessToken, 'other-access');
      expect(storage.value!.refreshToken, 'other-refresh');
    },
  );
  test(
    'failed refresh expires once and blocks later protected calls',
    () async {
      var refreshes = 0;
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) async {
          refreshes++;
          throw const FormatException('Invalid refresh token');
        }),
      );
      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      expect(session.status, SessionStatus.expired);
      expect(storage.value, isNull);
      final calls = adapter.calls;
      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      expect(adapter.calls, calls);
      expect(refreshes, 1);
    },
  );
  test('second 401 does not loop and expires the rejected session', () async {
    adapter.alwaysReject = true;
    var refreshes = 0;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshes++;
        return credentials('new', 'rotated');
      }),
    );
    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
    expect(refreshes, 1);
    expect(adapter.calls, 2);
    expect(session.isAuthenticated, false);
  });
  test('logout during refresh cannot resurrect session', () async {
    final refresh = Completer<SessionTokens>();
    final started = Completer<void>();
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) {
        started.complete();
        return refresh.future;
      }),
    );
    final result = expectLater(
      dio.get('/protected'),
      throwsA(isA<DioException>()),
    );
    await started.future;
    await session.logout();
    refresh.complete(credentials('new', 'rotated'));
    await result;
    expect(session.isAuthenticated, false);
    expect(storage.value, isNull);
  });
  test('public 401 never starts refresh', () async {
    var refreshes = 0;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshes++;
        return credentials('new', 'r');
      }),
    );
    await expectLater(
      dio.post('/auth/login', options: Options(extra: {'public': true})),
      throwsA(isA<DioException>()),
    );
    expect(refreshes, 0);
    expect(session.isAuthenticated, true);
  });
}
