import '../../../../core/storage/secure_storage_service.dart';
import 'auth_models.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';

/// CAP login contract: resultcode == 1 and an active mobile account.
/// A HTTP 200 alone never establishes an authenticated session.
class CapLoginResponse {
  const CapLoginResponse(this.user, this.tokens);
  final AuthUser user;
  final SessionTokens tokens;
  factory CapLoginResponse.parse(
    Map<String, dynamic> response,
    String username,
  ) {
    if (response['resultcode'] != 1) {
      throw const ApiException(UnauthorizedFailure());
    }
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing CAP user data');
    }
    if (data['User_MobileEnable'] == false ||
        data['User_MobileActivationState'] == false) {
      throw const ApiException(ServiceFailure('inactive_user'));
    }
    final access = data['AccessToken'];
    final refresh = data['RefreshToken'];
    final id = data['User_PK_ID'];
    final name = data['User_Name'];
    if (access is! String ||
        access.trim().isEmpty ||
        refresh is! String ||
        refresh.trim().isEmpty ||
        id is! num ||
        name is! String ||
        name.isEmpty) {
      throw const FormatException('Invalid CAP login response');
    }
    return CapLoginResponse(
      AuthUser(id: id.toString(), name: name),
      SessionTokens(access, refresh),
    );
  }
}
