import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:access_log_plus/app.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
import 'package:access_log_plus/core/network/dio_client.dart';
import 'package:access_log_plus/core/network/interceptors/auth_interceptor.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/authentication/data/api/auth_api_service.dart';
import 'package:access_log_plus/features/authentication/data/models/auth_models.dart';
import 'package:access_log_plus/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:access_log_plus/features/authentication/domain/usecases/forgot_password_use_case.dart';
import 'package:access_log_plus/features/authentication/presentation/bloc/forgot_password_cubit.dart';
import 'package:access_log_plus/screens/auth/auth_screens.dart';

import 'support/periodic_photo_fakes.dart' show MemoryTokenStorage;

class _Transport implements HttpClientAdapter {
  Map<String, dynamic> response = {
    'resultcode': 1,
    'data': {'emailSent': true, 'linkExpiresInMinutes': 47},
  };
  int httpStatus = 200;
  DioExceptionType? error;
  Completer<void>? pending;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    if (pending != null) await pending!.future;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      httpStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionManager session;
  late Dio dio;
  late _Transport transport;
  late AuthRepositoryImpl repository;
  late ForgotPasswordCubit cubit;
  late int refreshCalls;

  setUp(() {
    CapLocaleHolder.instance.update(const Locale('en'));
    session = SessionManager(MemoryTokenStorage());
    transport = _Transport();
    refreshCalls = 0;
    dio = DioClient.create(
      baseUrl: 'https://cap.test/api/',
      logging: true,
      availableCoordinates: () async => null,
    )..httpClientAdapter = transport;
    dio.interceptors.add(
      AuthInterceptor(dio, session, (_) async {
        refreshCalls++;
        throw StateError('Public password reset must not refresh a session');
      }),
    );
    final info = CapDeviceAppInfoProvider(
      osVersion: 'device-os',
      deviceType: 'Android',
      appVersion: '42',
      deviceToken: 'push-from-device',
      deviceIdentifierLoader: () async => 'installation-from-device',
    );
    repository = AuthRepositoryImpl(
      AuthApiService(dio),
      session,
      deviceInfo: info,
      requestContext: ApiRequestContextProvider(
        users: null,
        deviceInfo: info,
        currentUser: () =>
            throw StateError('Public request must not resolve user'),
      ),
    );
    cubit = ForgotPasswordCubit(ForgotPasswordUseCase(repository));
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    dio.close();
    await session.dispose();
    await services.reset();
    CapLocaleHolder.instance.update(const Locale('en'));
  });

  test(
    'public Retrofit endpoint sends exact CAP envelope with real provider values',
    () async {
      CapLocaleHolder.instance.update(const Locale('ar'));
      dio.options.headers['Authorization'] = 'Bearer stale-default-token';
      final result = await repository.requestPasswordReset('  surveyA  ');
      expect(result, isA<Success<ForgotPasswordResetData>>());
      final request = transport.calls.single;
      expect(
        request.uri.toString(),
        'https://cap.test/api/CAP/CapAuth/ForgotPasswordRequestReset',
      );
      expect(request.method, 'POST');
      expect(
        request.headers.keys.any((k) => k.toLowerCase() == 'authorization'),
        false,
      );
      expect(request.headers['lang'], 'ar');
      expect(request.data, {
        'userid': 0,
        'ipaddress': 'installation-from-device',
        'devicetoken': 'push-from-device',
        'osversion': 'device-os',
        'AppVersion': '42',
        'devicetype': 'Android',
        'lang': 'ar',
        'data': {'UserName': 'surveyA'},
      });
      expect(request.extra['public'], true);
      expect(refreshCalls, 0);
      expect(session.status, SessionStatus.signedOut);
    },
  );

  test(
    'empty username is rejected before HTTP at usecase and repository boundaries',
    () async {
      await cubit.submit('   ');
      expect(cubit.state.failure, isA<ValidationFailure>());
      expect(
        await repository.requestPasswordReset(''),
        isA<FailureResult<ForgotPasswordResetData>>(),
      );
      expect(transport.calls, isEmpty);
    },
  );

  for (final lang in ['ar', 'en']) {
    test(
      'business failure preserves $lang backend message even with non-success data',
      () async {
        CapLocaleHolder.instance.update(Locale(lang));
        transport.response = {
          'resultcode': 2,
          'resultmessageen': 'Unknown username',
          'resultmessagear': 'اسم المستخدم غير صالح',
          'data': {'emailSent': 'invalid-success-data'},
        };
        await cubit.submit('unknown');
        expect(cubit.state.status, ForgotPasswordStatus.failure);
        expect(
          cubit.state.failure!.message,
          lang == 'ar' ? 'اسم المستخدم غير صالح' : 'Unknown username',
        );
        expect(cubit.state.expiresInMinutes, isNull);
      },
    );
  }

  for (final data in [
    null,
    {'emailSent': false, 'linkExpiresInMinutes': 60},
    {'linkExpiresInMinutes': 60},
    {'emailSent': true},
    {'emailSent': true, 'linkExpiresInMinutes': 0},
    {'emailSent': true, 'linkExpiresInMinutes': -1},
    {'emailSent': 'true', 'linkExpiresInMinutes': 60},
    {'emailSent': true, 'linkExpiresInMinutes': '60'},
  ]) {
    test('unexpected/unsent reset payload is not successful: $data', () async {
      transport.response['data'] = data;
      await cubit.submit('surveyA');
      expect(cubit.state.status, ForgotPasswordStatus.failure);
      expect(cubit.state.expiresInMinutes, isNull);
    });
  }

  test(
    'expired session and a server 401 do not trigger refresh/logout/redirection',
    () async {
      await session.logout(expired: true);
      final generation = session.generation;
      transport.httpStatus = 401;
      await cubit.submit('surveyA');
      expect(cubit.state.status, ForgotPasswordStatus.failure);
      expect(transport.calls.length, 1);
      expect(refreshCalls, 0);
      expect(session.generation, generation);
      expect(session.status, SessionStatus.expired);
    },
  );

  test(
    'an existing authenticated session is neither used nor mutated',
    () async {
      session.startDemo();
      session.user = const SessionUser(id: '4099');
      final generation = session.generation;
      await cubit.submit('surveyA');
      expect((transport.calls.single.data as Map)['userid'], 0);
      expect(session.generation, generation);
      expect(session.userId, 4099);
      expect(refreshCalls, 0);
    },
  );

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('network failure is handled and can be retried: $type', () async {
      transport.error = type;
      await cubit.submit('surveyA');
      expect(cubit.state.status, ForgotPasswordStatus.failure);
      expect(
        cubit.state.failure,
        type == DioExceptionType.connectionError
            ? isA<NetworkFailure>()
            : isA<TimeoutFailure>(),
      );
      transport.error = null;
      await cubit.submit('surveyA');
      expect(cubit.state.status, ForgotPasswordStatus.success);
    });
  }

  test('HTTP 500 is a failure, never an email confirmation', () async {
    transport.httpStatus = 500;
    await cubit.submit('surveyA');
    expect(cubit.state.status, ForgotPasswordStatus.failure);
  });

  test(
    'rapid submissions share a single in-flight request and show dynamic expiry',
    () async {
      transport.pending = Completer<void>();
      final states = <ForgotPasswordStatus>[];
      final subscription = cubit.stream.listen(
        (state) => states.add(state.status),
      );
      final calls = List.generate(5, (_) => cubit.submit('surveyA'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.calls.length, 1);
      expect(cubit.state.status, ForgotPasswordStatus.loading);
      transport.pending!.complete();
      await Future.wait(calls);
      await Future<void>.delayed(Duration.zero);
      expect(states, [
        ForgotPasswordStatus.loading,
        ForgotPasswordStatus.success,
      ]);
      expect(cubit.state.expiresInMinutes, 47);
      await subscription.cancel();
    },
  );

  test(
    'disposing the screen/cubit during a request does not emit late states',
    () async {
      transport.pending = Completer<void>();
      final request = cubit.submit('surveyA');
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      transport.pending!.complete();
      await request;
      expect(cubit.isClosed, true);
    },
  );

  test(
    'reset HTTP request/response/error logs do not expose credentials or user data',
    () async {
      final original = debugPrint;
      final logs = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) =>
          logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      dio.options.headers['Authorization'] = 'Bearer never-log-me';
      await repository.requestPasswordReset('private-username');
      transport.httpStatus = 500;
      await repository.requestPasswordReset('private-username');
      expect(logs, isEmpty);
    },
  );

  test(
    'public metadata resolves and caches installation identifier without reading session',
    () async {
      var reads = 0;
      final info = CapDeviceAppInfoProvider(
        osVersion: 'x',
        deviceType: 'iOS',
        appVersion: '9',
        deviceIdentifierLoader: () async {
          reads++;
          return 'stable-install-id';
        },
      );
      final provider = ApiRequestContextProvider(
        users: null,
        deviceInfo: info,
        currentUser: () => throw StateError('must not read user'),
      );
      final requests = await Future.wait(
        List.generate(
          3,
          (_) => provider.wrapUnauthenticated(
            const ForgotPasswordRequestData('a'),
          ),
        ),
      );
      expect(
        requests.every(
          (r) => r.userId == 0 && r.deviceIdentifier == 'stable-install-id',
        ),
        true,
      );
      expect(reads, 1);
    },
  );

  test(
    'installation ID is generated once and survives a new provider instance',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final first = await CapDeviceAppInfoProvider().resolveDeviceIdentifier();
      final second = await CapDeviceAppInfoProvider().resolveDeviceIdentifier();
      expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(second, first);
      expect(first, isNot('FUH0216913004222'));
    },
  );

  test('a transient identifier lookup failure can be retried', () async {
    var reads = 0;
    final provider = CapDeviceAppInfoProvider(
      deviceIdentifierLoader: () async {
        if (++reads == 1) throw StateError('storage temporarily unavailable');
        return 'recovered-device-id';
      },
    );
    await expectLater(provider.resolveDeviceIdentifier(), throwsStateError);
    expect(await provider.resolveDeviceIdentifier(), 'recovered-device-id');
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
      'existing Login link opens reset UI in $language and returns after email success',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        services.registerFactory<ForgotPasswordCubit>(() => cubit);
        await tester.pumpWidget(const AccessLogApp());
        AccessLogApp.of(
          tester.element(find.byType(LoginScreen)),
        ).setLocale(Locale(language));
        await tester.pumpAndSettle();
        final link = find.text(
          language == 'en' ? 'Forgot password?' : 'نسيت كلمة المرور؟',
        );
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        final send = find.text(
          language == 'en' ? 'Send Reset Link' : 'إرسال رابط الاستعادة',
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(
          find.text(
            language == 'en' ? 'Enter your username.' : 'أدخل اسم المستخدم.',
          ),
          findsOneWidget,
        );
        expect(transport.calls, isEmpty);
        await tester.enterText(find.byType(TextFormField), 'surveyA');
        transport.pending = Completer<void>();
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pump(const Duration(milliseconds: 100));
        expect(transport.calls.length, 1);
        expect(cubit.state.status, ForgotPasswordStatus.loading);
        transport.pending!.complete();
        await tester.pumpAndSettle();
        expect(
          find.text(
            language == 'en'
                ? 'The link expires in 47 minutes.'
                : 'تنتهي صلاحية الرابط خلال 47 دقيقة.',
          ),
          findsOneWidget,
        );
        expect(find.byType(OtpVerificationScreen), findsNothing);
        expect(tester.takeException(), isNull);
        final back = find.text(
          language == 'en' ? 'Back to sign in' : 'العودة لتسجيل الدخول',
        );
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
