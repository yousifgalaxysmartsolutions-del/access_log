import '../../../../core/storage/secure_storage_service.dart';
import 'auth_models.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/cap_parse_diagnostics.dart';

/// CAP login contract: resultcode == 1 and an active mobile account.
/// A HTTP 200 alone never establishes an authenticated session.
class CapLoginResponse {
  const CapLoginResponse(this.user, this.tokens);
  final AuthUser user;
  final SessionTokens tokens;
  factory CapLoginResponse.parse(
    Map<String, dynamic> response,
    String username, {
    DateTime? receivedAt,
  }) {
    if (response['resultcode'] != 1) {
      throw const ApiException(UnauthorizedFailure());
    }
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing CAP user data');
    }
    final parsed = CapParseDiagnostics.decodeData(
      (raw) => LoginTokenData.fromJson(raw as Map<String, dynamic>),
      data,
      endpoint: 'CAP/CapAuth/Login',
      model: 'LoginTokenData',
    );
    if (parsed.mobileEnable == false || parsed.mobileActive == false) {
      throw const ApiException(ServiceFailure('inactive_user'));
    }
    final id = parsed.id;
    final name = parsed.name;
    if (id == null || name == null || name.isEmpty) {
      throw const FormatException('Invalid CAP login response');
    }
    return CapLoginResponse(
      AuthUser(id: id.toString(), name: name),
      SessionTokens.fromResponse(
        access: parsed.accessToken,
        refresh: parsed.refreshToken,
        lifetime: parsed.lifetime,
        refreshExpiry: parsed.refreshExpiry,
        now: receivedAt ?? DateTime.now().toUtc(),
      ),
    );
  }
}
