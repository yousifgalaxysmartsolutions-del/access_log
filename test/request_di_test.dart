import 'dart:convert';
import 'package:access_log_plus/features/incidents/domain/actions/incident_action_resolver_service.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/features/requests/presentation/bloc/request_list_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:access_log_plus/core/config/environment.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/interceptors/auth_interceptor.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/requests/data/api/request_api_service.dart';
import 'package:access_log_plus/features/requests/data/repositories/request_repository_impl.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_lookup_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_list_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/approve_request_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/reject_request_use_case.dart';

class _Storage implements TokenStorage, SessionUserStorage {
  @override
  Future<SessionTokens?> readTokens() async => SessionTokens(
    'test-access',
    'test-refresh',
    accessTokenExpiresAtUtc: DateTime.now().toUtc().add(
      const Duration(hours: 1),
    ),
    refreshTokenExpiresAtUtc: DateTime.now().toUtc().add(
      const Duration(days: 7),
    ),
  );
  @override
  Future<SessionUser?> readUser() async => const SessionUser(id: '4089');
  @override
  Future<void> writeTokens(SessionTokens value) async {}
  @override
  Future<void> writeUser(SessionUser value) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearUser() async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'resultcode': 1, 'data': {}}),
      200,
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
  test(
    'request read blocs are factories with independent state and no startup calls',
    () async {
      await configureDependencies(
        environment: const AppEnvironment(
          environment: Environment.development,
          baseUrl: 'https://cap.test',
          mockAuthentication: false,
        ),
        storage: _Storage(),
      );
      final first = services<RequestListBloc>();
      final second = services<RequestListBloc>();
      expect(first, isNot(same(second)));
      expect(first.state.loading, false);
      expect(second.state.lookupLoading, false);
      await first.close();
      await second.close();
    },
  );
  setUp(() async {
    await services.reset();
    PackageInfo.setMockInitialValues(
      appName: 'Test',
      packageName: 'test',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(() async => services.reset());
  Future<void> configure({bool mock = false}) => configureDependencies(
    environment: AppEnvironment(
      environment: Environment.development,
      baseUrl: 'https://cap.test',
      apiVersion: 'api',
      mockAuthentication: mock,
    ),
    storage: _Storage(),
  );

  test(
    'actual app setup resolves six lazy singletons and is repeatable',
    () async {
      await configure();
      expect(
        services<IncidentLookupStore>(),
        same(services<IncidentLookupStore>()),
      );
      expect(
        services<GetIncidentLookupUseCase>(),
        same(services<GetIncidentLookupUseCase>()),
      );
      expect(services<IncidentLookupStore>().current, isNull);
      expect(
        services<IncidentActionResolverService>(),
        same(services<IncidentActionResolverService>()),
      );
      final api = services<RequestApiService>();
      final repo = services<RequestRepository>();
      expect(repo, isA<RequestRepositoryImpl>());
      expect(
        services<GetRequestLookupUseCase>(),
        same(services<GetRequestLookupUseCase>()),
      );
      expect(
        services<GetRequestListUseCase>(),
        same(services<GetRequestListUseCase>()),
      );
      expect(
        services<ApproveRequestUseCase>(),
        same(services<ApproveRequestUseCase>()),
      );
      expect(
        services<RejectRequestUseCase>(),
        same(services<RejectRequestUseCase>()),
      );
      expect(services.isRegistered<ApiRequestContextProvider>(), true);
      await configure();
      expect(services<RequestApiService>(), same(api));
      expect(services<RequestRepository>(), same(repo));
    },
  );
  test(
    'resolved use case reaches shared Dio adapter and auth interceptor',
    () async {
      await configure();
      final shared = services<Dio>();
      expect(shared.interceptors.whereType<AuthInterceptor>().length, 1);
      final adapter = _Adapter();
      shared.httpClientAdapter = adapter;
      var intercepted = 0;
      shared.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            intercepted++;
            options.headers['X-Shared-Dio'] = 'yes';
            handler.next(options);
          },
        ),
      );
      // Construct service before making changes to shared Dio, then verify it
      // observes the same instance rather than a copied client.
      services<RequestApiService>();
      shared.options.headers['X-After-Resolution'] = 'same-instance';
      final result = await services<GetRequestLookupUseCase>()();
      expect(result, isA<Success>());
      expect(intercepted, 1);
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://cap.test/api/CAP/CapLookup/GetAllRequestLookup',
      );
      expect(request.headers['Authorization'], 'Bearer test-access');
      expect(request.headers['X-Shared-Dio'], 'yes');
      expect(request.headers['X-After-Resolution'], 'same-instance');
      final body = jsonDecode(jsonEncode(request.data)) as Map;
      expect(body['userid'], 4089);
      expect(body.containsKey('data'), false);
    },
  );
  test(
    'mock-auth setup still registers the requested graph without invoking it',
    () async {
      await configure(mock: true);
      expect(services<RequestRepository>(), isA<RequestRepositoryImpl>());
      expect(services<RequestApiService>(), isA<RequestApiService>());
      expect(
        services<GetRequestLookupUseCase>(),
        isA<GetRequestLookupUseCase>(),
      );
      expect(services<GetRequestListUseCase>(), isA<GetRequestListUseCase>());
      expect(services<ApproveRequestUseCase>(), isA<ApproveRequestUseCase>());
      expect(services<RejectRequestUseCase>(), isA<RejectRequestUseCase>());
    },
  );
}
