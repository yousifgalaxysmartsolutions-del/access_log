import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/features/authentication/data/models/auth_models.dart';
import 'package:access_log_plus/features/authentication/data/models/cap_login_response.dart';
import 'package:access_log_plus/core/network/api_exception.dart';

void main() {
  test('CAP request preserves envelope and credential casing', () {
    final json = const LoginRequest('engA', 'test-password').toJson();
    expect(json['userid'], 0);
    expect(json['data'], {'UserName': 'engA', 'Password': 'test-password'});
    expect(
      json.keys,
      containsAll([
        'ipaddress',
        'devicetoken',
        'osversion',
        'AppVersion',
        'devicetype',
        'lang',
      ]),
    );
  });
  test('unknown or rejected response cannot create a session', () {
    expect(
      () => CapLoginResponse.parse({'message': 'OK'}, 'engA'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => CapLoginResponse.parse({'success': false, 'token': 'x'}, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  Map<String, dynamic> success() => {
    'resultcode': 1,
    'data': {
      'User_PK_ID': 4099,
      'User_Name': 'engA',
      'User_MobileEnable': true,
      'User_MobileActivationState': true,
      'AccessToken': 'test-token',
      'RefreshToken': 'test-refresh',
    },
  };
  test('CAP success maps actual identity and both tokens', () {
    final value = CapLoginResponse.parse(success(), 'different-input');
    expect(value.user.id, '4099');
    expect(value.user.name, 'engA');
    expect(value.tokens.accessToken, 'test-token');
    expect(value.tokens.refreshToken, 'test-refresh');
  });
  test('failed resultcode rejects even with tokens', () {
    final response = success()..['resultcode'] = 0;
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  test('inactive mobile account rejects valid token response', () {
    final response = success();
    (response['data'] as Map<String, dynamic>)['User_MobileEnable'] = false;
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsA(isA<ApiException>()),
    );
  });
  test('missing tokens cannot establish session', () {
    final response = success();
    (response['data'] as Map<String, dynamic>).remove('AccessToken');
    expect(
      () => CapLoginResponse.parse(response, 'engA'),
      throwsFormatException,
    );
  });
}
