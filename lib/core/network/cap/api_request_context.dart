import '../../error/failure.dart';
import '../../storage/secure_storage_service.dart';
import '../result.dart';
import 'cap_device_app_info.dart';
import 'cap_request.dart';

/// Builds the shared CAP request envelope metadata.
///
/// Every CAP endpoint needs the same authenticated user and device context, so
/// it is resolved in exactly one place instead of being hardcoded per call.
class ApiRequestContextProvider {
  ApiRequestContextProvider({
    required SessionUserStorage? users,
    required CapDeviceAppInfoProvider deviceInfo,
  }) : _users = users,
       _deviceInfo = deviceInfo;

  final SessionUserStorage? _users;
  final CapDeviceAppInfoProvider _deviceInfo;

  Future<CapDeviceAppInfo> resolveDeviceInfo() => _deviceInfo.resolve();

  /// Uses the same authenticated context as ordinary requests, but explicitly
  /// opts into Sprint 1's metadata-only serialization. `wrap` stays unchanged.
  Future<Result<CapRequest<Null>>> wrapMetadataOnly({
    required String authenticationMessage,
  }) async {
    final result = await wrap<Null>(
      null,
      authenticationMessage: authenticationMessage,
    );
    return switch (result) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => Success(
        CapRequest.metadataOnly(
          userId: data.userId,
          deviceIdentifier: data.deviceIdentifier,
          deviceToken: data.deviceToken,
          osVersion: data.osVersion,
          appVersion: data.appVersion,
          deviceType: data.deviceType,
        ),
      ),
    };
  }

  /// Wraps [data] with the current user and device context.
  ///
  /// Fails when there is no signed-in user id: sending `0` would silently
  /// attribute the request to an unknown account, so the caller is told to sign
  /// in again instead.
  Future<Result<CapRequest<T>>> wrap<T>(
    T data, {
    required String authenticationMessage,
  }) async {
    final user = await _users?.readUser();
    final numericId = user?.numericId ?? 0;
    if (numericId <= 0) {
      return FailureResult(UnauthorizedFailure(authenticationMessage));
    }
    final info = await _deviceInfo.resolve();
    return Success(
      CapRequest<T>(
        userId: numericId,
        deviceIdentifier: defaultDeviceIdentifier,
        // Needs Verification: no push registration exists yet, so this is the
        // build-time override when present and an empty token otherwise.
        deviceToken: info.deviceToken ?? defaultDeviceToken,
        osVersion: info.osVersion,
        appVersion: info.appVersion,
        deviceType: info.deviceType,
        data: data,
      ),
    );
  }

  static const String defaultDeviceIdentifier = String.fromEnvironment(
    'CAP_DEVICE_ID',
    defaultValue: 'FUH0216913004222',
  );

  static const String defaultDeviceToken = String.fromEnvironment(
    'CAP_DEVICE_TOKEN',
    defaultValue: '',
  );
}
