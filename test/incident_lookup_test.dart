import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_lookup_models.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:access_log_plus/features/incidents/data/repositories/demo_incident_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'package:access_log_plus/features/authentication/data/models/auth_models.dart';
import 'package:access_log_plus/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:access_log_plus/features/authentication/domain/usecases/login_use_case.dart';
import 'package:access_log_plus/features/authentication/presentation/bloc/login_bloc.dart';
import 'package:access_log_plus/screens/dashboard/cap_dashboard_screen.dart';
import 'package:access_log_plus/screens/incidents/incident_list_screen.dart';

const fixture = {
  'resultcode': 1,
  'resultmessageen': 'Suceess Get data',
  'resultmessagear': 'Suceess Get data',
  'data': {
    'incidentType': [
      {'id': 1, 'name': 'X2 Interface Fault', 'code': 'X2 Interface Fault'},
      {'id': 2, 'name': 'Cell Unavailable', 'code': 'Cell Unavailable'},
    ],
    'status': [
      {'id': 1, 'name': 'Need Assign', 'code': 'NEED_ASSIGN'},
      {'id': 2, 'name': 'Need Approval', 'code': 'NEED_APPROVAL'},
      {'id': 3, 'name': 'Pending', 'code': 'PENDING'},
      {'id': 4, 'name': 'In Process', 'code': 'IN_PROCESS'},
      {'id': 5, 'name': 'Completed', 'code': 'COMPLETED'},
      {'id': 6, 'name': 'Cancelled', 'code': 'CANCELLED'},
      {'id': 7, 'name': 'Hold', 'code': 'HOLD'},
      {'id': 8, 'name': 'Rejected', 'code': 'FULLY_REJECTED'},
    ],
    'priority': [
      {'id': 1, 'name': 'High', 'code': 'High'},
      {'id': 2, 'name': 'Medium', 'code': 'Medium'},
      {'id': 3, 'name': 'Low', 'code': 'Low'},
    ],
    'alarmType': [
      {'id': 1, 'name': 'X2 Interface Fault', 'code': 'X2 Interface Fault'},
      {'id': 2, 'name': 'Cell Unavailable', 'code': 'Cell Unavailable'},
      {
        'id': 3,
        'name': 'GSM Cell out of Service',
        'code': 'GSM Cell out of Service',
      },
      {'id': 4, 'name': 'Fire Alarm', 'code': 'Fire Alarm'},
    ],
    'notificationType': [
      {'id': 1, 'name': 'manual', 'code': 'M'},
      {'id': 2, 'name': 'Auto', 'code': 'A'},
    ],
    'actionType': [
      {'id': 1, 'name': 'Assign', 'code': 'Assign'},
      {'id': 2, 'name': 'Cancel', 'code': 'Cancel'},
      {'id': 3, 'name': 'Approve', 'code': 'Approve'},
      {'id': 4, 'name': 'Reject', 'code': 'Reject'},
      {'id': 5, 'name': 'Intervention', 'code': 'Intervention'},
      {'id': 6, 'name': 'Renewal', 'code': 'Renewal'},
      {'id': 7, 'name': 'Departure', 'code': 'Departure'},
      {'id': 8, 'name': ' Hold', 'code': ' Hold'},
      {'id': 9, 'name': 'Complete', 'code': 'Complete'},
    ],
  },
};

class MemoryStorage implements TokenStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<SessionTokens?> readTokens() async => null;
  @override
  Future<void> writeTokens(SessionTokens tokens) async {}
}

class Adapter implements HttpClientAdapter {
  Map<String, dynamic> body = fixture;
  int status = 200;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
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

class LookupFake extends DemoIncidentRepository {
  final pending = <Completer<Result<IncidentLookupData>>>[];
  @override
  Future<Result<IncidentLookupData>> getIncidentLookup() {
    final value = Completer<Result<IncidentLookupData>>();
    pending.add(value);
    return value.future;
  }
}

class LoginFake extends DemoAuthRepository {
  LoginFake(super.session);
  bool fail = false;
  @override
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    if (fail) return const FailureResult(UnauthorizedFailure());
    await session.signIn(
      const SessionTokens('a', 'r'),
      user: const SessionUser(id: '9001', name: 'Engineer'),
      remember: false,
    );
    return const Success(AuthUser(id: '9001', name: 'Engineer'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionManager session;
  late Adapter adapter;
  late Dio dio;
  late IncidentRepositoryImpl repository;
  late IncidentLookupStore store;
  setUp(() async {
    session = SessionManager(MemoryStorage());
    await session.signIn(
      const SessionTokens('a', 'r'),
      user: const SessionUser(id: '9001'),
      remember: false,
    );
    adapter = Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
      ..httpClientAdapter = adapter;
    repository = IncidentRepositoryImpl(
      IncidentApiService(dio),
      ApiRequestContextProvider(
        users: null,
        currentUser: () => session.user,
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '18.4',
          deviceType: 'Android',
          appVersion: '42',
          deviceToken: 'runtime-device',
        ),
      ),
    );
    store = IncidentLookupStore(GetIncidentLookupUseCase(repository), session);
  });
  tearDown(() async {
    await services.reset();
    await store.dispose();
    await session.dispose();
    dio.close();
    CapLocaleHolder.instance.update(const Locale('en'));
  });

  test(
    'exact backend fixture preserves all six lookups and raw leading spaces',
    () async {
      final result = await GetIncidentLookupUseCase(repository)();
      final data = (result as Success<IncidentLookupData>).data;
      final expected = fixture['data']! as Map;
      final actual = {
        'incidentType': data.incidentType,
        'status': data.status,
        'priority': data.priority,
        'alarmType': data.alarmType,
        'notificationType': data.notificationType,
        'actionType': data.actionType,
      };
      for (final entry in actual.entries) {
        expect(
          entry.value
              .map(
                (item) => {'id': item.id, 'name': item.name, 'code': item.code},
              )
              .toList(),
          expected[entry.key],
        );
      }
      expect(data.actionType[7].name, ' Hold');
      expect(data.actionType[7].code, ' Hold');
      expect(() => data.status.clear(), throwsUnsupportedError);
    },
  );

  test(
    'service posts exact context envelope with data explicitly null',
    () async {
      await store.refresh();
      final request = adapter.calls.single;
      expect(request.method, 'POST');
      expect(request.path, 'CAP/CapLookup/GetAllIncidentLookup');
      expect(request.data, {
        'userid': 9001,
        'ipaddress': ApiRequestContextProvider.defaultDeviceIdentifier,
        'devicetoken': 'runtime-device',
        'osversion': '18.4',
        'AppVersion': '42',
        'devicetype': 'Android',
        'data': null,
      });
    },
  );

  test(
    'refresh always calls API; success replaces entire object; failure retains it',
    () async {
      await store.refresh();
      final a = store.current;
      adapter.body = {'resultcode': 1, 'data': {}};
      await store.refresh();
      final b = store.current;
      expect(identical(a, b), false);
      expect(b!.status, isEmpty);
      adapter.status = 500;
      expect(await store.refresh(), isA<FailureResult<IncidentLookupData>>());
      expect(store.current, same(b));
      expect(adapter.calls, hasLength(3));
      store.clear();
      expect(store.current, isNull);
      await store.refresh();
      expect(store.current, isNull);
    },
  );

  test('CAP failure localized and malformed DTO safely fails', () async {
    CapLocaleHolder.instance.update(const Locale('ar'));
    adapter.body = {
      'resultcode': 0,
      'resultmessagear': 'غير متاح',
      'data': null,
    };
    final result = await store.refresh();
    expect((result as FailureResult).failure.message, 'غير متاح');
    adapter.body = {
      'resultcode': 1,
      'data': {
        'status': [
          {'id': 'invalid'},
        ],
      },
    };
    expect(await store.refresh(), isA<FailureResult<IncidentLookupData>>());
    expect(store.current, isNull);
  });

  test(
    'logout clears immediately and invalid session never sends userid zero',
    () async {
      await store.refresh();
      await session.logout();
      expect(store.current, isNull);
      expect(await store.refresh(), isA<FailureResult<IncidentLookupData>>());
      expect(adapter.calls, hasLength(1));
    },
  );

  test(
    'overlap is deterministic and logout or clear discards late results',
    () async {
      final fake = LookupFake();
      final cache = IncidentLookupStore(
        GetIncidentLookupUseCase(fake),
        session,
      );
      final a = IncidentLookupData(), b = IncidentLookupData();
      final first = cache.refresh(), second = cache.refresh();
      fake.pending[1].complete(Success(b));
      await second;
      fake.pending[0].complete(Success(a));
      await first;
      expect(cache.current, same(b));
      final late = cache.refresh();
      await session.logout();
      await session.signIn(
        const SessionTokens('new', 'new'),
        user: const SessionUser(id: '9'),
      );
      fake.pending[2].complete(Success(a));
      await late;
      expect(cache.current, isNull);
      final cleared = cache.refresh();
      cache.clear();
      fake.pending[3].complete(Success(a));
      await cleared;
      expect(cache.current, isNull);
      await cache.dispose();
    },
  );

  test(
    'successful login triggers refresh after saving session; lookup failure independent',
    () async {
      await session.logout();
      adapter.status = 500;
      final auth = LoginFake(session);
      final bloc = LoginBloc(LoginUseCase(auth), lookup: store);
      final done = bloc.stream.firstWhere(
        (s) => s.status == LoginStatus.success,
      );
      bloc.add(const LoginSubmitted('user', 'password', false));
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(adapter.calls, hasLength(1));
      expect((adapter.calls.single.data as Map)['userid'], 9001);
      expect(session.isAuthenticated, true);
      expect(bloc.state.status, LoginStatus.success);
      await bloc.close();
      auth.fail = true;
      final failed = LoginBloc(LoginUseCase(auth), lookup: store);
      final failedDone = failed.stream.firstWhere(
        (s) => s.status == LoginStatus.failure,
      );
      failed.add(const LoginSubmitted('user', 'bad', false));
      await failedDone;
      expect(adapter.calls, hasLength(1));
      await failed.close();
    },
  );

  testWidgets('retained tabs refresh only when activated, not on rebuild', (
    tester,
  ) async {
    services.registerSingleton<IncidentLookupStore>(store);
    Widget tabs(int selected) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: Scaffold(
        body: IndexedStack(
          index: selected,
          children: [
            CapDashboardScreen(isActive: selected == 0),
            IncidentListScreen(isActive: selected == 1),
          ],
        ),
      ),
    );
    for (final (selected, expected) in [
      (0, 1),
      (0, 1),
      (1, 2),
      (0, 3),
      (1, 4),
    ]) {
      await tester.pumpWidget(tabs(selected));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.calls, hasLength(expected));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'home then incident list each refresh even with a previously loaded cache',
    (tester) async {
      services.registerSingleton<IncidentLookupStore>(store);
      await tester.runAsync(() async {
        await store.refresh();
      });
      expect(adapter.calls, hasLength(1));
      expect(store.current, isNotNull);
      Widget app(Widget screen) => MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: screen),
      );
      await tester.pumpWidget(app(const CapDashboardScreen()));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.calls, hasLength(2));
      await tester.pumpWidget(app(const IncidentListScreen()));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.calls, hasLength(3));
      await tester.pumpWidget(app(const CapDashboardScreen()));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(adapter.calls, hasLength(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
