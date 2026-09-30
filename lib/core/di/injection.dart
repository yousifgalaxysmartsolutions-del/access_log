import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
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
import '../../features/authentication/data/models/auth_models.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/login_use_case.dart';
import '../../features/authentication/presentation/bloc/login_bloc.dart';

final services = GetIt.instance;
Future<void> configureDependencies({
  AppEnvironment? environment,
  TokenStorage? storage,
}) async {
  if (services.isRegistered<SessionManager>()) return;
  final config = environment ?? AppEnvironment.fromDefines();
  services.registerSingleton<AppEnvironment>(config);
  services.registerSingleton<TokenStorage>(storage ?? SecureStorageService());
  final session = SessionManager(services<TokenStorage>());
  if (!config.mockAuthentication) await session.restore();
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
  dio.interceptors.add(
    AuthInterceptor(
      dio,
      session,
      (token) async {
        if (config.mockAuthentication) {
          return const SessionTokens('demo-access', 'demo-refresh');
        }
        final refreshApi = AuthApiService(refreshDio);
        final response = (await refreshApi.refresh(RefreshTokenRequest(token))).data;
        if (response['resultcode'] != 1) {
          throw const FormatException('Refresh token failed');
        }
        final data = response['data'];
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Missing CAP refresh data');
        }
        final access = data['AccessToken'];
        final refresh = data['RefreshToken'];
        if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) {
          throw const FormatException('Invalid CAP refresh tokens');
        }
        return SessionTokens(access, refresh);
      },
    ),
  );
  services.registerSingleton<Dio>(dio, dispose: (d) => d.close(force: true));
  services.registerLazySingleton<AuthApiService>(
    () => AuthApiService(services<Dio>()),
  );
  services.registerLazySingleton<AuthRepository>(
    () => config.mockAuthentication
        ? DemoAuthRepository(session)
        : AuthRepositoryImpl(services<AuthApiService>(), session),
  );
  services.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(services<AuthRepository>()),
  );
  services.registerFactory<LoginBloc>(
    () => LoginBloc(services<LoginUseCase>()),
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
}
