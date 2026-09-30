class AuthUser {
  const AuthUser({required this.id, required this.name});
  final String id, name;
  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'].toString(), name: json['name'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class LoginRequest {
  const LoginRequest(this.username, this.password);
  final String username, password;
  Map<String, dynamic> toJson() => {
    'userid': 0,
    'ipaddress': const String.fromEnvironment(
      'CAP_DEVICE_ID',
      defaultValue: 'FUH0216913004222',
    ),
    'devicetoken': const String.fromEnvironment(
      'CAP_DEVICE_TOKEN',
      defaultValue: 'testtokens',
    ),
    'osversion': const String.fromEnvironment(
      'CAP_OS_VERSION',
      defaultValue: '15.1',
    ),
    'AppVersion': const String.fromEnvironment(
      'CAP_APP_VERSION',
      defaultValue: '1',
    ),
    'devicetype': const String.fromEnvironment(
      'CAP_DEVICE_TYPE',
      defaultValue: 'iOS',
    ),
    'lang': const String.fromEnvironment('CAP_LANGUAGE', defaultValue: 'en'),
    'data': {'UserName': username, 'Password': password},
  };
}

class RefreshTokenRequest {
  const RefreshTokenRequest(this.refreshToken);
  final String refreshToken;
  Map<String, dynamic> toJson() => {
    'userid': 0,
    'ipaddress': const String.fromEnvironment(
      'CAP_DEVICE_ID',
      defaultValue: 'FUH0216913004222',
    ),
    'devicetoken': const String.fromEnvironment(
      'CAP_DEVICE_TOKEN',
      defaultValue: 'testtokens',
    ),
    'osversion': const String.fromEnvironment(
      'CAP_OS_VERSION',
      defaultValue: '15.1',
    ),
    'AppVersion': const String.fromEnvironment(
      'CAP_APP_VERSION',
      defaultValue: '1',
    ),
    'devicetype': const String.fromEnvironment(
      'CAP_DEVICE_TYPE',
      defaultValue: 'iOS',
    ),
    'data': {'RefreshToken': refreshToken},
  };
}
