import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/interceptors/auth_interceptor.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';

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
  bool alwaysReject = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{}',
      !alwaysReject && options.headers['Authorization'] == 'Bearer new'
          ? 200
          : 401,
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
    await session.signIn(const SessionTokens('old', 'refresh'));
    adapter = TestAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/v1'))
      ..httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close();
    await session.dispose();
  });

  test('concurrent 401s refresh once and replay all requests', () async {
    var refreshes = 0;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const SessionTokens('new', 'rotated');
      }),
    );
    final responses = await Future.wait(
      List.generate(6, (_) => dio.get('/protected')),
    );
    expect(responses.every((r) => r.statusCode == 200), true);
    expect(refreshes, 1);
    expect(storage.value?.refreshToken, 'rotated');
  });
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
  test(
    'second 401 does not loop or expire a valid refreshed session',
    () async {
      adapter.alwaysReject = true;
      var refreshes = 0;
      dio.interceptors.add(
        AuthInterceptor(dio, session, (_) async {
          refreshes++;
          return const SessionTokens('new', 'rotated');
        }),
      );
      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      expect(refreshes, 1);
      expect(adapter.calls, 2);
      expect(session.isAuthenticated, true);
    },
  );
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
    refresh.complete(const SessionTokens('new', 'rotated'));
    await result;
    expect(session.isAuthenticated, false);
    expect(storage.value, isNull);
  });
  test('public 401 never starts refresh', () async {
    var refreshes = 0;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshes++;
        return const SessionTokens('new', 'r');
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
