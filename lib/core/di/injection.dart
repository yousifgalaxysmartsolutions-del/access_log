import '../../features/incidents/data/repositories/incident_action_configuration_repository_impl.dart';
import '../../features/incidents/data/repositories/system_gps_configuration_repository_impl.dart';
import '../../features/incidents/domain/repositories/system_gps_configuration_repository.dart';
import '../../features/incidents/domain/usecases/incident_geofence_use_case.dart';
import '../../features/requests/data/repositories/request_creation_repository_impl.dart';
import '../../features/requests/domain/repositories/request_creation_repository.dart';
import '../../features/requests/domain/usecases/incident_request_use_case.dart';
import '../../features/incidents/data/repositories/incident_execution_repository_impl.dart';
import '../../features/incidents/domain/repositories/incident_execution_repository.dart';
import '../../features/incidents/domain/usecases/incident_execution_use_case.dart';
import '../../features/incidents/domain/repositories/incident_action_configuration_repository.dart';
import '../../features/incidents/domain/usecases/get_incident_action_configuration_use_case.dart';
import 'package:dio/dio.dart';
import '../../features/authentication/domain/usecases/forgot_password_use_case.dart';
import '../../features/authentication/presentation/bloc/forgot_password_cubit.dart';
import '../../features/periodic_photo/data/today_in_process_store.dart';
import '../../features/periodic_photo/domain/today_in_process_incident_service.dart';
import '../../features/reports/data/repositories/engineers_activity_report_repository_impl.dart';
import '../../features/reports/domain/repositories/engineers_activity_report_repository.dart';
import '../../features/reports/domain/usecases/get_engineers_activity_report_use_case.dart';
import '../../features/reports/presentation/bloc/engineers_activity_report_cubit.dart';
import '../../features/incidents/presentation/bloc/incident_map_cubit.dart';
import '../../features/reports/data/repositories/requests_path_report_repository_impl.dart';
import '../../features/reports/domain/repositories/requests_path_report_repository.dart';
import '../../features/reports/domain/usecases/get_requests_path_report_use_case.dart';
import '../../features/reports/presentation/bloc/requests_path_report_cubit.dart';
import '../../features/reports/data/repositories/engineer_locations_report_repository_impl.dart';
import '../../features/reports/domain/repositories/engineer_locations_report_repository.dart';
import '../../features/reports/domain/usecases/get_engineer_locations_report_use_case.dart';
import '../../features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import '../../features/reports/data/api/report_api_service.dart';
import '../../features/reports/data/repositories/incident_report_repository_impl.dart';
import '../../features/reports/domain/repositories/incident_report_repository.dart';
import '../../features/reports/domain/usecases/incident_report_use_cases.dart';
import '../../features/reports/presentation/bloc/incident_report_cubit.dart';
import '../../features/incidents/domain/actions/incident_action_resolver_service.dart';
import '../../features/incidents/data/incident_lookup_store.dart';
import '../../features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'package:get_it/get_it.dart';
import '../../features/requests/presentation/bloc/request_list_bloc.dart';
import '../../features/requests/data/api/request_api_service.dart';
import '../../features/requests/data/repositories/request_repository_impl.dart';
import '../../features/requests/domain/repositories/request_repository.dart';
import '../../features/requests/domain/usecases/get_request_lookup_use_case.dart';
import '../../features/requests/domain/usecases/get_request_list_use_case.dart';
import '../../features/requests/domain/usecases/get_request_details_use_case.dart';
import '../../features/requests/presentation/bloc/request_details_cubit.dart';
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
import '../context/active_incident_context.dart';
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

import '../../features/forms/data/api/cap_form_api_service.dart';
import '../../features/forms/data/repositories/cap_form_repository_impl.dart';
import '../../features/forms/domain/repositories/cap_form_repository.dart';
import '../../features/forms/domain/usecases/cap_form_use_cases.dart';
import '../../features/forms/presentation/bloc/cap_form_cubit.dart';

import '../../features/gps_tracking/data/api/gps_tracking_api_service.dart';
import '../../features/gps_tracking/data/local/local_gps_store.dart';
import '../../features/gps_tracking/data/native/method_channel_background_location_service.dart';
import '../../features/gps_tracking/data/repositories/gps_tracking_sync_repository_impl.dart';
import '../../features/gps_tracking/domain/background_location_service.dart';
import '../../features/gps_tracking/domain/connectivity_service.dart';
import '../../features/gps_tracking/domain/gps_capture_sync_bridge.dart';
import '../../features/gps_tracking/domain/gps_requirement_gate.dart';
import '../../features/gps_tracking/domain/gps_tracking_manager.dart';
import '../../features/gps_tracking/domain/gps_tracking_sync_service.dart';
import '../../features/gps_tracking/domain/repositories/gps_tracking_sync_repository.dart';
import '../../features/gps_tracking/presentation/gps_tracking_cubit.dart';
import '../../features/forms/presentation/widgets/cap_form_capture.dart';
import '../../features/periodic_photo/data/api/periodic_photo_api_service.dart';
import '../../features/periodic_photo/data/periodic_photo_retain_store.dart';
import '../../features/periodic_photo/data/periodic_photo_schedule_store.dart';
import '../../features/periodic_photo/data/repositories/periodic_photo_repository_impl.dart';
import '../../features/periodic_photo/domain/periodic_photo_coordinator.dart';
import '../../features/periodic_photo/domain/periodic_photo_gate.dart';
import '../../features/periodic_photo/domain/repositories/periodic_photo_repository.dart';

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
  // Centralized "which incident is the user inside" context. The periodic-photo
  // requirement reads `uploadIncidentId` from it instead of inferring anything
  // from routes; incident screens only publish enter/leave.
  services.registerSingleton<ActiveIncidentContext>(
    ActiveIncidentContext(),
    dispose: (context) => context.dispose(),
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
            requestContext: services<ApiRequestContextProvider>(),
          ),
  );
  services.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(services<AuthRepository>()),
  );
  services.registerLazySingleton<ForgotPasswordUseCase>(
    () => ForgotPasswordUseCase(services<AuthRepository>()),
  );
  services.registerFactory<ForgotPasswordCubit>(
    () => ForgotPasswordCubit(services<ForgotPasswordUseCase>()),
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
  registerFormDependencies();
  registerIncidentActionConfigurationDependencies();
  registerGpsTrackingDependencies();
  registerPeriodicPhotoDependencies();
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
  services.registerLazySingleton<GetRequestDetailsUseCase>(
    () => GetRequestDetailsUseCase(services<RequestRepository>()),
  );
  services.registerFactory<RequestDetailsCubit>(
    () => RequestDetailsCubit(services<GetRequestDetailsUseCase>()),
  );
  services.registerLazySingleton<RequestCreationRepository>(
    () => RequestCreationRepositoryImpl(
      services<RequestApiService>(),
      services<ApiRequestContextProvider>(),
      inProcessIncidents: services.isRegistered<TodayInProcessIncidentService>()
          ? services<TodayInProcessIncidentService>()
          : null,
      incidentDetails: services.isRegistered<IncidentDetailsRepository>()
          ? services<IncidentDetailsRepository>()
          : null,
    ),
  );
  services.registerLazySingleton<IncidentRequestUseCase>(
    () => IncidentRequestUseCase(services<RequestCreationRepository>()),
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
      isSupervisor: () => services<SessionManager>().user?.isSupervisor == true,
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
  if (!services.isRegistered<DashboardApiService>()) {
    services.registerLazySingleton<DashboardApiService>(
      () => DashboardApiService(services<Dio>()),
    );
  }
  services.registerLazySingleton<ReportApiService>(
    () => ReportApiService(services<Dio>()),
  );
  services.registerLazySingleton<EngineersActivityReportRepository>(
    () => EngineersActivityReportRepositoryImpl(
      services<ReportApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetEngineersActivityReportUseCase>(
    () => GetEngineersActivityReportUseCase(
      services<EngineersActivityReportRepository>(),
    ),
  );
  services.registerFactory<EngineersActivityReportCubit>(
    () => EngineersActivityReportCubit(
      getReport: services<GetEngineersActivityReportUseCase>(),
      getLocations: services<GetReportLocationsUseCase>(),
      loadTeam: services<IncidentExecutionUseCase>().getTeam,
      currentUser: () => session.user,
    ),
  );
  services.registerLazySingleton<RequestsPathReportRepository>(
    () => RequestsPathReportRepositoryImpl(
      services<ReportApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetRequestsPathReportUseCase>(
    () =>
        GetRequestsPathReportUseCase(services<RequestsPathReportRepository>()),
  );
  services.registerFactory<RequestsPathReportCubit>(
    () => RequestsPathReportCubit(
      getReport: services<GetRequestsPathReportUseCase>(),
      getLookup: services<GetRequestLookupUseCase>(),
      getLocations: services<GetReportLocationsUseCase>(),
    ),
  );
  services.registerLazySingleton<IncidentReportRepository>(
    () => IncidentReportRepositoryImpl(
      services<ReportApiService>(),
      services<DashboardApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<EngineerLocationsReportRepository>(
    () => EngineerLocationsReportRepositoryImpl(
      services<ReportApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetEngineerLocationsReportUseCase>(
    () => GetEngineerLocationsReportUseCase(
      services<EngineerLocationsReportRepository>(),
    ),
  );
  services.registerFactory<EngineerLocationsReportCubit>(
    () => EngineerLocationsReportCubit(
      getReport: services<GetEngineerLocationsReportUseCase>(),
      loadTeam: services<IncidentExecutionUseCase>().getTeam,
      currentUser: () => session.user,
    ),
  );
  services.registerLazySingleton<GetIncidentReportUseCase>(
    () => GetIncidentReportUseCase(services<IncidentReportRepository>()),
  );
  services.registerLazySingleton<GetReportLocationsUseCase>(
    () => GetReportLocationsUseCase(services<IncidentReportRepository>()),
  );
  services.registerFactory<IncidentReportCubit>(
    () => IncidentReportCubit(
      getReport: services<GetIncidentReportUseCase>(),
      getLocations: services<GetReportLocationsUseCase>(),
      lookupStore: services<IncidentLookupStore>(),
    ),
  );

  services.registerLazySingleton<GetIncidentLookupUseCase>(
    () => GetIncidentLookupUseCase(services<IncidentRepository>()),
  );
  services.registerLazySingleton<IncidentLookupStore>(
    () => IncidentLookupStore(services<GetIncidentLookupUseCase>(), session),
    dispose: (store) => store.dispose(),
  );
  services.registerLazySingleton<IncidentActionResolverService>(
    () => IncidentActionResolverService(services<IncidentLookupStore>()),
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
  services.registerFactory<IncidentMapCubit>(
    () => IncidentMapCubit(
      getIncidents: services<GetIncidentListUseCase>(),
      getRequests: services<GetIncidentRequestsUseCase>(),
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

/// Registers lazy form dependencies without making API requests.
void registerFormDependencies() {
  if (services.isRegistered<CapFormRepository>()) return;
  services.registerLazySingleton<CapFormApiService>(
    () => CapFormApiService(services<Dio>()),
  );
  services.registerLazySingleton<CapFormRepository>(
    () => CapFormRepositoryImpl(
      services<CapFormApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetCapFormUseCase>(
    () => GetCapFormUseCase(services<CapFormRepository>()),
  );
  services.registerLazySingleton<SubmitIncidentFormUseCase>(
    () => SubmitIncidentFormUseCase(services<CapFormRepository>()),
  );
  services.registerFactory<CapFormCubit>(
    () => CapFormCubit(
      services<GetCapFormUseCase>(),
      submit: services<SubmitIncidentFormUseCase>(),
    ),
  );
}

void registerIncidentActionConfigurationDependencies() {
  if (!services.isRegistered<SystemGpsConfigurationRepository>()) {
    services.registerLazySingleton<SystemGpsConfigurationRepository>(
      () => SystemGpsConfigurationRepositoryImpl(
        services<IncidentApiService>(),
        services<ApiRequestContextProvider>(),
      ),
    );
    services.registerLazySingleton<IncidentGeofenceUseCase>(
      () =>
          IncidentGeofenceUseCase(services<SystemGpsConfigurationRepository>()),
    );
  }
  if (!services.isRegistered<IncidentExecutionUseCase>()) {
    services.registerLazySingleton<IncidentExecutionUseCase>(
      () => IncidentExecutionUseCase(services<IncidentExecutionRepository>()),
    );
  }
  if (!services.isRegistered<IncidentExecutionRepository>()) {
    services.registerLazySingleton<IncidentExecutionRepository>(
      () => IncidentExecutionRepositoryImpl(
        services<IncidentApiService>(),
        services<ApiRequestContextProvider>(),
        services<CapFormRepository>(),
        getAvailableLocation: CapNativeFormCapture().getAvailableLocation,
        incidentDetails: services.isRegistered<IncidentDetailsRepository>()
            ? services<IncidentDetailsRepository>()
            : null,
        inProcessIncidents:
            services.isRegistered<TodayInProcessIncidentService>()
            ? services<TodayInProcessIncidentService>()
            : null,
      ),
    );
  }
  if (services.isRegistered<IncidentActionConfigurationRepository>()) return;
  if (!services.isRegistered<IncidentApiService>()) {
    services.registerLazySingleton<IncidentApiService>(
      () => IncidentApiService(services<Dio>()),
    );
  }
  services.registerLazySingleton<IncidentActionConfigurationRepository>(
    () => IncidentActionConfigurationRepositoryImpl(
      services<IncidentApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<GetIncidentActionConfigurationUseCase>(
    () => GetIncidentActionConfigurationUseCase(
      services<IncidentActionConfigurationRepository>(),
    ),
  );
}

/// Registers the continuous background-tracking graph.
///
/// The engine itself is native; these registrations are the Flutter-side
/// bridge plus local store reader. Nothing is invoked at setup time, so tests
/// that only call [configureDependencies] stay side-effect free.
void registerGpsTrackingDependencies() {
  if (services.isRegistered<GpsTrackingManager>()) return;
  services.registerLazySingleton<BackgroundLocationService>(
    MethodChannelBackgroundLocationService.new,
  );
  services.registerLazySingleton<LocalGpsStore>(LocalGpsStore.new);
  services.registerLazySingleton<GpsTrackingManager>(
    () => GpsTrackingManager(
      services<BackgroundLocationService>(),
      services<SystemGpsConfigurationRepository>(),
    ),
    dispose: (manager) => manager.dispose(),
  );

  // One centralized GPS requirement state for the whole authenticated app.
  // Enforced app-wide by `AppRequirementGuard`, never per screen.
  services.registerLazySingleton<GpsRequirementGate>(
    () => GpsRequirementGate(services<GpsTrackingManager>()),
    dispose: (gate) => gate.dispose(),
  );

  // Server-sync graph. Separate from the tracking engine so an API failure can
  // never stop capture; nothing runs until a trigger calls the service.
  services.registerLazySingleton<GpsTrackingApiService>(
    () => GpsTrackingApiService(services<Dio>()),
  );
  services.registerLazySingleton<GpsTrackingSyncRepository>(
    () => GpsTrackingSyncRepositoryImpl(
      services<GpsTrackingApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<ConnectivityService>(() {
    final host = Uri.tryParse(services<AppEnvironment>().apiUrl)?.host ?? '';
    return InternetConnectivityService(host: host);
  });
  services.registerLazySingleton<GpsTrackingSyncService>(
    () => GpsTrackingSyncService(
      store: services<LocalGpsStore>(),
      repository: services<GpsTrackingSyncRepository>(),
      connectivity: services<ConnectivityService>(),
      session: services<SessionManager>(),
    ),
    dispose: (service) => service.dispose(),
  );

  // Native "point captured" → immediate sync trigger. Best-effort and
  // independent: capture/persistence never wait on this path.
  services.registerLazySingleton<GpsCaptureSyncBridge>(
    () => GpsCaptureSyncBridge(
      services<BackgroundLocationService>(),
      services<GpsTrackingSyncService>(),
    ),
    dispose: (bridge) => bridge.dispose(),
  );
  services.registerFactory<GpsTrackingCubit>(
    () => GpsTrackingCubit(
      services<GpsTrackingManager>(),
      sync: services<GpsTrackingSyncService>(),
    ),
  );
}

/// Registers the periodic-photo requirement graph.
///
/// Everything is lazy: nothing loads configuration, opens storage, starts a
/// timer or sends a request during setup, so tests that only call
/// [configureDependencies] stay side-effect free.
///
/// The timing policy lives in [PeriodicPhotoCoordinator] (config + persisted
/// deadline), the requirement lifecycle in [PeriodicPhotoGate]; UI is wired by
/// `AppRequirementGuard`, never by a screen.
void registerPeriodicPhotoDependencies() {
  if (services.isRegistered<PeriodicPhotoGate>()) return;
  services.registerLazySingleton<TodayInProcessStore>(TodayInProcessStore.new);
  services.registerLazySingleton<TodayInProcessIncidentService>(
    () => TodayInProcessIncidentService(
      session: services<SessionManager>(),
      store: services<TodayInProcessStore>(),
    ),
    dispose: (service) => service.dispose(),
  );
  services.registerLazySingleton<PeriodicPhotoScheduleStore>(
    PeriodicPhotoScheduleStore.new,
  );
  services.registerLazySingleton<PeriodicPhotoRetainStore>(
    PeriodicPhotoRetainStore.new,
  );
  services.registerLazySingleton<PeriodicPhotoApiService>(
    () => PeriodicPhotoApiService(services<Dio>()),
  );
  services.registerLazySingleton<PeriodicPhotoRepository>(
    () => PeriodicPhotoRepositoryImpl(
      services<PeriodicPhotoApiService>(),
      services<ApiRequestContextProvider>(),
    ),
  );
  services.registerLazySingleton<PeriodicPhotoCoordinator>(
    () => PeriodicPhotoCoordinator(
      configuration: services<SystemGpsConfigurationRepository>(),
      store: services<PeriodicPhotoScheduleStore>(),
      incidents: services<TodayInProcessIncidentService>(),
    ),
    dispose: (coordinator) => coordinator.dispose(),
  );
  // One centralized periodic-photo requirement for the whole authenticated
  // app. Enforced app-wide by `AppRequirementGuard`, never per screen.
  services.registerLazySingleton<PeriodicPhotoGate>(
    () => PeriodicPhotoGate(
      coordinator: services<PeriodicPhotoCoordinator>(),
      repository: services<PeriodicPhotoRepository>(),
      retainStore: services<PeriodicPhotoRetainStore>(),
      activeIncident: services<ActiveIncidentContext>(),
      incidents: services<TodayInProcessIncidentService>(),
      session: services<SessionManager>(),
      // Camera reuse: the existing foreground, user-initiated capture flow
      // (image_picker → device camera, 16 MB guard). Never a gallery image.
      capturePhoto: () => CapNativeFormCapture().capturePhoto(),
    ),
    dispose: (gate) => gate.dispose(),
  );
}
