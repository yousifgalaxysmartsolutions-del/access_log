import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/network/interceptors/auth_interceptor.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/features/authentication/data/api/auth_api_service.dart';
import 'package:access_log_plus/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:access_log_plus/features/authentication/data/models/auth_models.dart';
import 'package:access_log_plus/features/authentication/data/models/cap_login_response.dart';
import 'package:access_log_plus/core/network/api_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('CAP request preserves envelope and credential casing', () {
    final json = const LoginRequest('engA', 'test-password').toJson();
    expect(json['userid'], 0);
    expect(json['data'], {'UserName': 'engA', 'Password': 'test-password'});
    expect(
      json.keys,
      containsAll([
        'ipaddress',
        'devicetoken',
        'osversion',
        'AppVersion',
        'devicetype',
        'lang',
      ]),
    );
  });
  test('unknown or rejected response cannot create a session', () {
    expect(
      () => CapLoginResponse.parse({'message': 'OK'}, 'engA'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => CapLoginResponse.parse({'success': false, 'token': 'x'}, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  Map<String, dynamic> success() => {
    'resultcode': 1,
    'data': {
      'User_PK_ID': 4099,
      'User_Name': 'engA',
      'User_MobileEnable': true,
      'User_MobileActivationState': true,
      'AccessToken': 'test-token',
      'RefreshToken': 'test-refresh',
      'AccessTokenExpiresInSeconds': 3600,
      'RefreshTokenExpiresAtUtc': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String(),
    },
  };
  test('CAP success maps actual identity and both tokens', () {
    final value = CapLoginResponse.parse(success(), 'different-input');
    expect(value.user.id, '4099');
    expect(value.user.name, 'engA');
    expect(value.tokens.accessToken, 'test-token');
    expect(value.tokens.refreshToken, 'test-refresh');
  });
  test('failed resultcode rejects even with tokens', () {
    final response = success()..['resultcode'] = 0;
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  test('inactive mobile account rejects valid token response', () {
    final response = success();
    (response['data'] as Map<String, dynamic>)['User_MobileEnable'] = false;
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  test('missing tokens cannot establish session', () {
    final response = success();
    (response['data'] as Map<String, dynamic>).remove('AccessToken');
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsFormatException,
    );
  });

  test(
    'real login persists identity, both credentials and calculated expiries',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureStorageService();
      final now = DateTime.utc(2026, 10, 4, 12);
      final session = SessionManager(store, store)..now = () => now;
      final adapter = _AuthAdapter(success());
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          dio,
          session,
          (_) async => throw StateError('Login must stay public'),
        ),
      );
      final repository = AuthRepositoryImpl(AuthApiService(dio), session);
      final result = await repository.login(
        username: 'engA',
        password: 'test-only',
      );
      expect(result, isA<Success<AuthUser>>());
      final persisted = await store.readTokens();
      expect(persisted!.accessToken, 'test-token');
      expect(persisted.refreshToken, 'test-refresh');
      expect(
        persisted.accessTokenExpiresAtUtc,
        now.add(const Duration(hours: 1)),
      );
      expect(persisted.refreshTokenExpiresAtUtc, isNotNull);
      expect((await store.readUser())!.id, '4099');
      expect(adapter.requests.single.extra['public'], true);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        false,
      );
      dio.close();
      await session.dispose();
    },
  );

  test(
    'real lower-case refresh uses metadata provider, zero userid and new UTC expiry',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureStorageService();
      final now = DateTime.utc(2026, 10, 4, 12);
      final session = SessionManager(store, store)..now = () => now;
      await session.signIn(
        SessionTokens(
          'old',
          'OLD',
          accessTokenExpiresAtUtc: now,
          refreshTokenExpiresAtUtc: now.add(const Duration(days: 1)),
        ),
        user: const SessionUser(id: '4098', name: 'Engineer'),
      );
      final adapter = _AuthAdapter({
        'resultcode': 1,
        'data': {
          'accessToken': 'new',
          'refreshToken': 'NEW',
          'accessTokenExpiresInSeconds': 3600,
          'refreshTokenExpiresAtUtc': '2026-10-11T14:34:28.0422592+03:00',
        },
      });
      final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      final appDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
      final info = CapDeviceAppInfoProvider(
        osVersion: '17.0',
        deviceType: 'Android',
        appVersion: '9',
        deviceToken: 'device-test',
      );
      final repo = AuthRepositoryImpl(
        AuthApiService(appDio),
        session,
        refreshApi: AuthApiService(refreshDio),
        deviceInfo: info,
      );
      await session.ensureFresh(repo.refresh);
      await session.ensureFresh(repo.refresh, force: true);
      expect(adapter.requests.length, 2);
      final body = adapter.requests.first.data as Map;
      expect(body['userid'], 0);
      expect(body['data'], {'RefreshToken': 'OLD'});
      expect((adapter.requests.last.data as Map)['data'], {
        'RefreshToken': 'NEW',
      });
      expect(body['osversion'], '17.0');
      expect(body['devicetype'], 'Android');
      expect(body['AppVersion'], '9');
      expect(body['devicetoken'], 'device-test');
      expect(adapter.requests.first.path, '/CAP/CapAuth/RefreshToken');
      expect(adapter.requests.first.extra['public'], true);
      expect(
        adapter.requests.first.headers.containsKey('Authorization'),
        false,
      );
      expect(session.tokens!.accessToken, 'new');
      expect(
        session.tokens!.accessTokenExpiresAtUtc,
        now.add(const Duration(hours: 1)),
      );
      expect(session.tokens!.refreshTokenExpiresAtUtc!.hour, 11);
      expect(session.userId, 4098);
      expect((await store.readTokens())!.toJson(), session.tokens!.toJson());
      final context = ApiRequestContextProvider(users: store, deviceInfo: info);
      final envelope = await context.wrapMetadataOnly(
        authenticationMessage: 'missing',
      );
      expect((envelope as Success).data.toJson()['userid'], 4098);
      expect((envelope as Success).data.toJson().containsKey('data'), false);
      appDio.close();
      refreshDio.close();
      await session.dispose();
    },
  );

  test('refresh rejects failed or incomplete real responses', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureStorageService();
    final session = SessionManager(store)
      ..now = () => DateTime.utc(2026, 10, 4);
    final valid = <String, dynamic>{
      'accessToken': 'a',
      'refreshToken': 'r',
      'accessTokenExpiresInSeconds': 3600,
      'refreshTokenExpiresAtUtc': '2026-10-11T00:00:00Z',
    };
    final adapter = _AuthAdapter({});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    final repo = AuthRepositoryImpl(
      AuthApiService(dio),
      session,
      refreshApi: AuthApiService(dio),
      deviceInfo: CapDeviceAppInfoProvider(appVersion: '1'),
    );
    final bodies = <Map<String, dynamic>>[
      {'resultcode': 0, 'data': valid},
      {'resultcode': 1},
      for (final field in valid.keys)
        {
          'resultcode': 1,
          'data': {...valid, field: null},
        },
      {
        'resultcode': 1,
        'data': {...valid, 'accessTokenExpiresInSeconds': 0},
      },
      {
        'resultcode': 1,
        'data': {...valid, 'refreshTokenExpiresAtUtc': 'bad'},
      },
      {
        'resultcode': 1,
        'data': {...valid, 'refreshToken': ' '},
      },
      {
        'resultcode': 1,
        'data': {...valid, 'accessTokenExpiresInSeconds': 'wrong-type'},
      },
    ];
    for (final body in bodies) {
      adapter.body = body;
      await expectLater(repo.refresh('old'), throwsA(isA<Exception>()));
    }
    adapter.body = {'resultcode': 1, 'data': valid};
    adapter.status = 401;
    await expectLater(repo.refresh('old'), throwsA(isA<DioException>()));
    dio.close();
    await session.dispose();
  });
}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter(this.body);
  Map<String, dynamic> body;
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
