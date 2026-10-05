import 'package:dio/dio.dart';
import '../../features/incidents/data/incident_lookup_store.dart';
import '../../features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'package:get_it/get_it.dart';
import '../../features/requests/presentation/bloc/request_list_bloc.dart';
import '../../features/requests/data/api/request_api_service.dart';
import '../../features/requests/data/repositories/request_repository_impl.dart';
import '../../features/requests/domain/repositories/request_repository.dart';
import '../../features/requests/domain/usecases/get_request_lookup_use_case.dart';
import '../../features/requests/domain/usecases/get_request_list_use_case.dart';
import '../../features/requests/domain/usecases/approve_request_use_case.dart';
import '../../features/requests/domain/usecases/reject_request_use_case.dart';
import '../../ai_copilot/ai_provider_config.dart';
import '../../ai_copilot/ai_copilot_service.dart';
import '../../features/copilot/data/api/copilot_api_service.dart';
import '../../features/copilot/data/retrofit_ai_transport.dart';
import '../../features/copilot/data/copilot_repository.dart';
import '../../features/copilot/domain/complete_copilot_use_case.dart';
import '../config/environment.dart';
import '../network/dio_client.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../session/session_manager.dart';
import '../storage/secure_storage_service.dart';
import '../../features/authentication/data/api/auth_api_service.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/login_use_case.dart';
import '../../features/authentication/domain/usecases/get_user_profile_use_case.dart';
import '../../features/authentication/presentation/bloc/login_bloc.dart';
import '../../features/dashboard/data/api/dashboard_api_service.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/data/repositories/demo_dashboard_repository.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/get_dashboard_stats_use_case.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/incidents/data/api/incident_api_service.dart';
import '../../features/incidents/data/repositories/demo_incident_details_repository.dart';
import '../../features/incidents/data/repositories/demo_incident_repository.dart';
import '../../features/incidents/data/repositories/incident_details_repository_impl.dart';
import '../../features/incidents/data/repositories/incident_repository_impl.dart';
import '../../features/incidents/domain/repositories/incident_details_repository.dart';
import '../../features/incidents/domain/repositories/incident_repository.dart';
import '../../features/incidents/domain/usecases/get_incident_details_use_case.dart';
import '../../features/incidents/domain/usecases/get_incident_list_use_case.dart';
import '../../features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import '../../features/incidents/domain/usecases/get_incident_timeline_use_case.dart';
import '../../features/incidents/presentation/bloc/incident_details_bloc.dart';
import '../network/cap/api_request_context.dart';
import '../network/cap/cap_device_app_info.dart';

final services = GetIt.instance;
Future<void> configureDependencies({
  AppEnvironment? environment,
  TokenStorage? storage,
  SessionUserStorage? userStorage,
}) async {
  if (services.isRegistered<SessionManager>()) return;
  final config = environment ?? AppEnvironment.fromDefines();
  services.registerSingleton<AppEnvironment>(config);
  final tokenStorage = storage ?? SecureStorageService();
  services.registerSingleton<TokenStorage>(tokenStorage);
  // The session user must come from the same secure store as the tokens. A
  // custom `TokenStorage` that cannot store users simply leaves it in memory.
  final SessionUserStorage? users =
      userStorage ??
      (tokenStorage is SessionUserStorage
          ? tokenStorage as SessionUserStorage
          : null);
  final session = SessionManager(services<TokenStorage>(), users);
  services.registerSingleton<SessionManager>(
    session,
    dispose: (s) => s.dispose(),
  );
  final dio = DioClient.create(baseUrl: config.apiUrl, logging: config.logging);
  // Separate refresh transport prevents interceptor recursion/deadlock.
  final refreshDio = DioClient.create(
    baseUrl: config.apiUrl,
    logging: config.logging,
  );
  services.registerSingleton<Dio>(
    refreshDio,
    instanceName: 'refresh',
    dispose: (d) => d.close(force: true),
  );
  services.registerSingleton<Dio>(dio, dispose: (d) => d.close(force: true));
  services.registerLazySingleton<AuthApiService>(
    () => AuthApiService(services<Dio>()),
  );
  services.registerLazySingleton<AuthRepository>(
    () => config.mockAuthentication
        ? DemoAuthRepository(session)
        : AuthRepositoryImpl(
            services<AuthApiService>(),
            session,
            refreshApi: AuthApiService(refreshDio),
            deviceInfo: services<CapDeviceAppInfoProvider>(),
          ),
  );
  services.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(services<AuthRepository>()),
  );
  services.registerLazySingleton<GetUserProfileUseCase>(
    () => GetUserProfileUseCase(services<AuthRepository>()),
  );
  services.registerFactory<LoginBloc>(
    () => LoginBloc(
      services<LoginUseCase>(),
      lookup: services<IncidentLookupStore>(),
    ),
  );
  services.registerLazySingleton<Dio>(
    () => DioClient.create(
      baseUrl: AiProviderConfig.baseUrl,
      logging: config.logging,
    ),
    instanceName: 'copilot',
    dispose: (d) => d.close(force: true),
  );
  services.registerLazySingleton<CopilotApiService>(
    () => CopilotApiService(services<Dio>(instanceName: 'copilot')),
  );
  services.registerLazySingleton<AiCopilotClient>(
    () => AiCopilotService.fromEnvironment(
      transport: RetrofitAiTransport(api: services<CopilotApiService>()),
    ),
  );
  services.registerLazySingleton<CopilotRepository>(
    () => CopilotRepository(services<AiCopilotClient>()),
  );
  services.registerLazySingleton<CompleteCopilotUseCase>(
    () => CompleteCopilotUseCase(services<CopilotRepository>()),
  );
  registerDashboardDependencies(session, config);
  registerRequestDependencies();
  final auth = services<AuthRepository>();
  dio.interceptors.add(AuthInterceptor(dio, session, auth.refresh));
  // Finish restoration before runApp chooses its initial authenticated route.
  if (!config.mockAuthentication) await session.restore(refresh: auth.refresh);
}

/// Uses the existing authenticated Dio and CAP context. Registration is lazy:
/// no requests are sent during setup. The read Bloc is screen-scoped; no UI is wired.
void registerRequestDependencies() {
  if (services.isRegistered<RequestRepository>()) return;
  services.registerLazySingleton<RequestApiService>(
    () => RequestApiService(services<Dio>()),
  );
  services.registerLazySingleton<RequestRepository>(
    () => RequestRepositoryImpl(
      services<RequestApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetRequestLookupUseCase>(
    () => GetRequestLookupUseCase(services<RequestRepository>()),
  );
  services.registerLazySingleton<GetRequestListUseCase>(
    () => GetRequestListUseCase(services<RequestRepository>()),
  );
  services.registerLazySingleton<ApproveRequestUseCase>(
    () => ApproveRequestUseCase(services<RequestRepository>()),
  );
  services.registerLazySingleton<RejectRequestUseCase>(
    () => RejectRequestUseCase(services<RequestRepository>()),
  );
  services.registerFactory<RequestListBloc>(
    () => RequestListBloc(
      getRequestLookup: services<GetRequestLookupUseCase>(),
      getRequestList: services<GetRequestListUseCase>(),
      approveRequest: services<ApproveRequestUseCase>(),
      rejectRequest: services<RejectRequestUseCase>(),
    ),
  );
}

/// Registers the dashboard and incident reads.
///
/// Mock-auth mode swaps in prototype repositories behind the same interfaces, so
/// the dashboard screen, bloc and tests are identical either way.
void registerDashboardDependencies(
  SessionManager session,
  AppEnvironment config,
) {
  if (services.isRegistered<ApiRequestContextProvider>()) return;

  services.registerLazySingleton<CapDeviceAppInfoProvider>(
    CapDeviceAppInfoProvider.new,
  );
  services.registerLazySingleton<ApiRequestContextProvider>(
    () => ApiRequestContextProvider(
      users: session.users,
      currentUser: () => session.user,
      deviceInfo: services<CapDeviceAppInfoProvider>(),
    ),
  );

  if (config.mockAuthentication) {
    services.registerLazySingleton<DashboardRepository>(
      DemoDashboardRepository.new,
    );
    services.registerLazySingleton<IncidentRepository>(
      DemoIncidentRepository.new,
    );
    services.registerLazySingleton<IncidentDetailsRepository>(
      DemoIncidentDetailsRepository.new,
    );
  } else {
    services.registerLazySingleton<DashboardApiService>(
      () => DashboardApiService(services<Dio>()),
    );
    services.registerLazySingleton<IncidentApiService>(
      () => IncidentApiService(services<Dio>()),
    );
    services.registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        services<DashboardApiService>(),
        services<ApiRequestContextProvider>(),
      ),
    );
    services.registerLazySingleton<IncidentRepository>(
      () => IncidentRepositoryImpl(
        services<IncidentApiService>(),
        services<ApiRequestContextProvider>(),
      ),
    );
    services.registerLazySingleton<IncidentDetailsRepository>(
      () => IncidentDetailsRepositoryImpl(
        services<IncidentApiService>(),
        services<ApiRequestContextProvider>(),
      ),
    );
  }

  // Session-level lookup, independent from incident action configuration.
  services.registerLazySingleton<GetIncidentLookupUseCase>(
    () => GetIncidentLookupUseCase(services<IncidentRepository>()),
  );
  services.registerLazySingleton<IncidentLookupStore>(
    () => IncidentLookupStore(services<GetIncidentLookupUseCase>(), session),
    dispose: (store) => store.dispose(),
  );

  // Registered for both branches: the repository is either the CAP-backed
  // implementation or the prototype one, so the details screen resolves a bloc
  // in mock builds too.
  services.registerLazySingleton<GetIncidentDetailsUseCase>(
    () => GetIncidentDetailsUseCase(services<IncidentDetailsRepository>()),
  );
  services.registerLazySingleton<GetIncidentTimelineUseCase>(
    () => GetIncidentTimelineUseCase(services<IncidentDetailsRepository>()),
  );
  services.registerLazySingleton<GetIncidentRequestsUseCase>(
    () => GetIncidentRequestsUseCase(services<IncidentDetailsRepository>()),
  );

  services.registerLazySingleton<GetDashboardStatsUseCase>(
    () => GetDashboardStatsUseCase(services<DashboardRepository>()),
  );
  services.registerLazySingleton<GetIncidentListUseCase>(
    () => GetIncidentListUseCase(services<IncidentRepository>()),
  );
  services.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      getDashboardStats: services<GetDashboardStatsUseCase>(),
      getIncidentList: services<GetIncidentListUseCase>(),
    ),
  );
  // Screen-scoped, so each details screen gets its own bloc.
  services.registerFactory<IncidentDetailsBloc>(
    () => IncidentDetailsBloc(
      getIncidentDetails: services<GetIncidentDetailsUseCase>(),
      getIncidentTimeline: services<GetIncidentTimelineUseCase>(),
      getIncidentRequests: services<GetIncidentRequestsUseCase>(),
    ),
  );
}
