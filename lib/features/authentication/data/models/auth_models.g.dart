// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginTokenData _$LoginTokenDataFromJson(Map<String, dynamic> json) =>
    LoginTokenData(
      id: (json['User_PK_ID'] as num?)?.toInt(),
      name: json['User_Name'] as String?,
      mobileEnable: json['User_MobileEnable'] as bool?,
      mobileActive: json['User_MobileActivationState'] as bool?,
      accessToken: json['AccessToken'] as String?,
      refreshToken: json['RefreshToken'] as String?,
      lifetime: (json['AccessTokenExpiresInSeconds'] as num?)?.toInt(),
      refreshExpiry: json['RefreshTokenExpiresAtUtc'] as String?,
    );

RefreshTokenData _$RefreshTokenDataFromJson(Map<String, dynamic> json) =>
    RefreshTokenData(
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      accessTokenExpiresInSeconds: (json['accessTokenExpiresInSeconds'] as num?)
          ?.toInt(),
      refreshTokenExpiresAtUtc: json['refreshTokenExpiresAtUtc'] as String?,
    );

Map<String, dynamic> _$RefreshTokenRequestDataToJson(
  RefreshTokenRequestData instance,
) => <String, dynamic>{'RefreshToken': instance.refreshToken};
