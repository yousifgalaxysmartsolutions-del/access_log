import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionTokens {
  const SessionTokens(this.accessToken, this.refreshToken);
  final String accessToken, refreshToken;
  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'] as String;
    final refresh = json['refreshToken'] as String? ?? '';
    if (access.isEmpty) {
      throw const FormatException('Empty tokens');
    }
    return SessionTokens(access, refresh);
  }
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

abstract interface class TokenStorage {
  Future<SessionTokens?> readTokens();
  Future<void> writeTokens(SessionTokens tokens);
  Future<void> clear();
}

class SecureStorageService implements TokenStorage {
  SecureStorageService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'access_log.session.v1';
  @override
  Future<SessionTokens?> readTokens() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return SessionTokens.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  // Both tokens share one record so token rotation cannot leave a mixed pair.
  @override
  Future<void> writeTokens(SessionTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
