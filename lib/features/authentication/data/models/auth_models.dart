class AuthUser {
  const AuthUser({required this.id, required this.name});
  final String id, name;
  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'].toString(), name: json['name'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class UserProfile {
  final int userId;
  final String userName;
  final String? fullName;
  final String? email;
  final String phoneNumber;
  final String userTypeEn;
  final String userRegion;
  final String userTypeAr;
  final String userDevice;
  final String userImageUrl;
  final bool? userNotificationEnable;

  UserProfile({
    required this.userId,
    required this.userName,
    this.fullName,
    this.email,
    required this.phoneNumber,
    required this.userTypeEn,
    required this.userRegion,
    required this.userTypeAr,
    required this.userDevice,
    required this.userImageUrl,
    this.userNotificationEnable,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String imageUrl = json['UserImageUrl'] as String? ?? '';
    // CAP sometimes prepends credentials or prefixes like 'dfms@123' to the URL
    if (imageUrl.contains('http')) {
      imageUrl = imageUrl.substring(imageUrl.indexOf('http'));
    }

    return UserProfile(
      userId: json['UserID'] as int,
      userName: json['UserName'] as String,
      fullName: json['FullName'] as String?,
      email: json['Email'] as String?,
      phoneNumber: json['PhoneNumber'] as String,
      userTypeEn: json['UserTypeEn'] as String,
      userRegion: json['UserRegion'] as String,
      userTypeAr: json['UserTypeAr'] as String,
      userDevice: json['UserDevice'] as String,
      userImageUrl: imageUrl,
      userNotificationEnable: json['User_NotificationEnable'] as bool?,
    );
  }
}

class UserProfileRequest {
  final int userId;
  UserProfileRequest({required this.userId});

  Map<String, dynamic> toJson() => {
    'userid': userId,
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
    'data': null,
  };
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
