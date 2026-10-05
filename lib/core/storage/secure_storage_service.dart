import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionTokens {
  const SessionTokens(
    this.accessToken,
    this.refreshToken, {
    this.accessTokenExpiresAtUtc,
    this.refreshTokenExpiresAtUtc,
  });
  final String accessToken, refreshToken;
  final DateTime? accessTokenExpiresAtUtc, refreshTokenExpiresAtUtc;
  static const safetyWindow = Duration(seconds: 60);
  bool needsRefresh(DateTime now) =>
      accessToken.trim().isEmpty ||
      accessTokenExpiresAtUtc == null ||
      !now.toUtc().isBefore(
        accessTokenExpiresAtUtc!.toUtc().subtract(safetyWindow),
      );
  bool canRefresh(DateTime now) =>
      refreshToken.trim().isNotEmpty &&
      refreshTokenExpiresAtUtc != null &&
      now.toUtc().isBefore(refreshTokenExpiresAtUtc!.toUtc());

  static SessionTokens fromResponse({
    required String? access,
    required String? refresh,
    required int? lifetime,
    required String? refreshExpiry,
    required DateTime now,
  }) {
    final expires = refreshExpiry == null
        ? null
        : DateTime.tryParse(refreshExpiry);
    if (access == null ||
        access.trim().isEmpty ||
        refresh == null ||
        refresh.trim().isEmpty ||
        lifetime == null ||
        lifetime <= 0 ||
        expires == null ||
        !expires.isUtc ||
        !expires.isAfter(now.toUtc())) {
      throw const FormatException(
        'Invalid authentication credentials or expiry',
      );
    }
    return SessionTokens(
      access,
      refresh,
      accessTokenExpiresAtUtc: now.toUtc().add(Duration(seconds: lifetime)),
      refreshTokenExpiresAtUtc: expires.toUtc(),
    );
  }

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'] as String;
    final refresh = json['refreshToken'] as String? ?? '';
    if (access.isEmpty) {
      throw const FormatException('Empty tokens');
    }
    return SessionTokens(
      access,
      refresh,
      accessTokenExpiresAtUtc: DateTime.tryParse(
        json['accessTokenExpiresAtUtc'] as String? ?? '',
      )?.toUtc(),
      refreshTokenExpiresAtUtc: DateTime.tryParse(
        json['refreshTokenExpiresAtUtc'] as String? ?? '',
      )?.toUtc(),
    );
  }
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAtUtc': accessTokenExpiresAtUtc
        ?.toUtc()
        .toIso8601String(),
    'refreshTokenExpiresAtUtc': refreshTokenExpiresAtUtc
        ?.toUtc()
        .toIso8601String(),
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
