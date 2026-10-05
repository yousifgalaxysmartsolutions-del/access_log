import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/result.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/cap_login_response.dart';
import '../../domain/repositories/auth_repository.dart';
import '../api/auth_api_service.dart';
import '../models/auth_models.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../../../core/network/cap/cap_device_app_info.dart';
import '../../../../core/network/cap/general_response.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this.api,
    this.session, {
    AuthApiService? refreshApi,
    CapDeviceAppInfoProvider? deviceInfo,
  }) : _refreshApi = refreshApi,
       _deviceInfo = deviceInfo ?? CapDeviceAppInfoProvider();
  final AuthApiService api;
  final SessionManager session;
  final AuthApiService? _refreshApi;
  final CapDeviceAppInfoProvider _deviceInfo;
  @override
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
    bool remember = true,
  }) => apiGuard(() async {
    final response = (await api.login(LoginRequest(username, password))).data;
    final parsed = CapLoginResponse.parse(
      response,
      username,
      receivedAt: session.now().toUtc(),
    );
    // The CAP envelope needs `userid`, so the signed-in user has to survive the
    // login call instead of being returned and discarded.
    await session.signIn(
      parsed.tokens,
      user: SessionUser(id: parsed.user.id, name: parsed.user.name),
      remember: remember,
    );
    return parsed.user;
  });

  @override
  Future<SessionTokens> refresh(String refreshToken) async {
    final transport = _refreshApi;
    if (transport == null) {
      throw const FormatException('Refresh transport unavailable');
    }
    final info = await _deviceInfo.resolve();
    final response = await transport.refresh(
      CapRequest(
        userId: 0,
        deviceIdentifier: ApiRequestContextProvider.defaultDeviceIdentifier,
        deviceToken:
            info.deviceToken ?? ApiRequestContextProvider.defaultDeviceToken,
        osVersion: info.osVersion,
        appVersion: info.appVersion,
        deviceType: info.deviceType,
        data: RefreshTokenRequestData(refreshToken),
      ),
    );
    final receivedAt = session.now().toUtc();
    final data = GeneralResponse.parseOrThrow<RefreshTokenData>(
      response,
      (raw) => RefreshTokenData.fromJson(raw as Map<String, dynamic>),
      isArabic: false,
      fallbackMessage: 'Unable to refresh session',
      endpoint: 'CAP/CapAuth/RefreshToken',
      model: 'RefreshTokenData',
    ).data!;
    return SessionTokens.fromResponse(
      access: data.accessToken,
      refresh: data.refreshToken,
      lifetime: data.accessTokenExpiresInSeconds,
      refreshExpiry: data.refreshTokenExpiresAtUtc,
      now: receivedAt,
    );
  }

  @override
  Future<Result<UserProfile>> getUserProfile(int userId) => apiGuard(() async {
    final response = (await api.getUserProfile(
      UserProfileRequest(userId: userId),
    )).data;
    if (response['resultcode'] != 1) {
      throw ApiException(
        ServerFailure(response['resultmessageen'] ?? 'Failed to get profile'),
      );
    }
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile data');
    }
    return UserProfile.fromJson(data);
  });
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this.session);
  final SessionManager session;
  @override
  Future<Result<AuthUser>> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    session.startDemo();
    return const Success(AuthUser(id: 'demo-engineer', name: 'Ahmed Mohamed'));
  }

  @override
  Future<SessionTokens> refresh(String refreshToken) async {
    return const SessionTokens('demo-access', 'demo-refresh');
  }

  @override
  Future<Result<UserProfile>> getUserProfile(int userId) async {
    return Success(
      UserProfile(
        userId: userId,
        userName: 'gsmm',
        phoneNumber: '50987866',
        userTypeEn: 'SuperVisior',
        userRegion: 'Orange',
        userTypeAr: 'SuperVisior',
        userDevice: 'testtokens',
        userImageUrl:
            'http://www.ileadcloud.com:8765/BridgeForce_dev/images/Photo.jpg',
      ),
    );
  }
}
