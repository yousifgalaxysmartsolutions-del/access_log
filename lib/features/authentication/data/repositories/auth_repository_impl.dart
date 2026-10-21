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
import '../../../../core/network/cap/cap_locale_holder.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this.api,
    this.session, {
    AuthApiService? refreshApi,
    CapDeviceAppInfoProvider? deviceInfo,
    ApiRequestContextProvider? requestContext,
  }) : _refreshApi = refreshApi,
       _requestContext = requestContext,
       _deviceInfo = deviceInfo ?? CapDeviceAppInfoProvider();
  final AuthApiService api;
  final SessionManager session;
  final AuthApiService? _refreshApi;
  final CapDeviceAppInfoProvider _deviceInfo;
  final ApiRequestContextProvider? _requestContext;

  @override
  Future<Result<ForgotPasswordResetData>> requestPasswordReset(
    String username,
  ) => apiGuard(() async {
    if (username.trim().isEmpty) {
      throw const ApiException(ValidationFailure());
    }
    final context =
        _requestContext ??
        ApiRequestContextProvider(users: null, deviceInfo: _deviceInfo);
    final envelope = await context.wrapUnauthenticated(
      ForgotPasswordRequestData(username.trim()),
    );
    final response = await api.forgotPasswordRequestReset(envelope);
    final arabic = CapLocaleHolder.instance.isArabic;
    final fallback = arabic
        ? 'تعذّر إرسال رابط إعادة تعيين كلمة المرور. حاول مرة أخرى.'
        : 'Unable to send the password reset link. Please try again.';
    // Evaluate business status before decoding the success-only payload.
    final metadata = GeneralResponse.parse<Object?>(response, (raw) => raw);
    if (!metadata.isSuccess) {
      throw ApiException(
        ServiceFailure(
          'cap_result_${metadata.resultCode}',
          metadata.messageFor(isArabic: arabic) ?? fallback,
        ),
      );
    }
    final raw = metadata.data;
    if (raw is! Map<String, dynamic>) {
      throw ApiException(ServiceFailure('reset_link_unavailable', fallback));
    }
    // Recovery responses may contain email addresses/reset links. Do not dump
    // even malformed payloads into parse diagnostics for this public endpoint.
    late final ForgotPasswordResetData data;
    try {
      data = ForgotPasswordResetData.fromJson(raw);
    } on Object {
      throw ApiException(ServiceFailure('reset_link_invalid', fallback));
    }
    if (data.emailSent != true || (data.linkExpiresInMinutes ?? 0) <= 0) {
      throw ApiException(ServiceFailure('reset_link_unavailable', fallback));
    }
    return data;
  });
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
      user: SessionUser(
        id: parsed.user.id,
        name: parsed.user.name,
        userTypeEn: parsed.user.userTypeEn,
        userTypeAr: parsed.user.userTypeAr,
      ),
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
  Future<Result<ForgotPasswordResetData>> requestPasswordReset(
    String username,
  ) async => FailureResult(
    ServiceFailure(
      'demo_reset_unavailable',
      CapLocaleHolder.instance.isArabic
          ? 'إرسال رابط الاستعادة متاح عند الاتصال بالخادم الفعلي.'
          : 'Reset emails require the live authentication service.',
    ),
  );
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
