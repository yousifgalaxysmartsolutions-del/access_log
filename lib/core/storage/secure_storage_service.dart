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

/// Identity of the signed-in CAP user.
///
/// Lives in core so the CAP request envelope can resolve the `userid` field
/// without the data layer depending on the authentication feature's models.
class SessionUser {
  const SessionUser({required this.id, this.name});

  /// `User_PK_ID` as text, matching how `AuthUser` exposes it.
  final String id;
  final String? name;

  /// Numeric form the CAP envelope expects (`"userid": 4098`).
  int get numericId => int.tryParse(id.trim()) ?? 0;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    if (id.isEmpty) throw const FormatException('Empty user id');
    final name = json['name'] as String?;
    return SessionUser(
      id: id,
      name: (name == null || name.isEmpty) ? null : name,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, if (name != null) 'name': name};
}

/// Deliberately separate from [TokenStorage] so token rotation keeps its
/// single-record invariant and existing storage implementations stay valid.
abstract interface class SessionUserStorage {
  Future<SessionUser?> readUser();
  Future<void> writeUser(SessionUser user);
  Future<void> clearUser();
}

class SecureStorageService implements TokenStorage, SessionUserStorage {
  SecureStorageService([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'access_log.session.v1';
  static const _userKey = 'access_log.session.user.v1';
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

  @override
  Future<SessionUser?> readUser() async {
    final value = await _storage.read(key: _userKey);
    if (value == null) return null;
    try {
      return SessionUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on FormatException {
      await clearUser();
      return null;
    } on TypeError {
      await clearUser();
      return null;
    }
  }

  @override
  Future<void> writeUser(SessionUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  @override
  Future<void> clearUser() => _storage.delete(key: _userKey);
}
