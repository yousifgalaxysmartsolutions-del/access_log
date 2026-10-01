import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';

class _MemoryTokens implements TokenStorage {
  SessionTokens? tokens;
  @override
  Future<void> clear() async => tokens = null;
  @override
  Future<SessionTokens?> readTokens() async => tokens;
  @override
  Future<void> writeTokens(SessionTokens value) async => tokens = value;
}

class _MemoryUsers implements SessionUserStorage {
  SessionUser? user;
  @override
  Future<void> clearUser() async => user = null;
  @override
  Future<SessionUser?> readUser() async => user;
  @override
  Future<void> writeUser(SessionUser value) async => user = value;
}

void main() {
  test('signIn persists tokens and user together', () async {
    final tokens = _MemoryTokens();
    final users = _MemoryUsers();
    final session = SessionManager(tokens, users);

    await session.signIn(
      const SessionTokens('access', 'refresh'),
      user: const SessionUser(id: '4098', name: 'Engineer'),
      remember: true,
    );

    expect(session.isAuthenticated, isTrue);
    expect(session.userId, 4098);
    expect(tokens.tokens?.accessToken, 'access');
    expect(users.user?.id, '4098');
    await session.dispose();
  });

  test('signIn without remember clears stored user', () async {
    final tokens = _MemoryTokens();
    final users = _MemoryUsers();
    users.user = const SessionUser(id: '1');
    final session = SessionManager(tokens, users);

    await session.signIn(const SessionTokens('a', 'r'), remember: false);

    expect(users.user, isNull);
    await session.dispose();
  });

  test('restore recovers both tokens and user', () async {
    final tokens = _MemoryTokens()..tokens = const SessionTokens('a', 'r');
    final users = _MemoryUsers()..user = const SessionUser(id: '77');
    final session = SessionManager(tokens, users);

    await session.restore();

    expect(session.isAuthenticated, isTrue);
    expect(session.userId, 77);
    await session.dispose();
  });

  test('rotate preserves the user identity', () async {
    final tokens = _MemoryTokens();
    final users = _MemoryUsers();
    final session = SessionManager(tokens, users);
    await session.signIn(
      const SessionTokens('a', 'r'),
      user: const SessionUser(id: '4098'),
    );

    final ok = await session.rotate(
      const SessionTokens('a2', 'r2'),
      session.generation,
    );

    expect(ok, isTrue);
    expect(session.tokens?.accessToken, 'a2');
    expect(session.userId, 4098);
    await session.dispose();
  });

  test('logout clears the user', () async {
    final tokens = _MemoryTokens();
    final users = _MemoryUsers();
    final session = SessionManager(tokens, users);
    await session.signIn(
      const SessionTokens('a', 'r'),
      user: const SessionUser(id: '5'),
    );

    await session.logout();

    expect(session.userId, 0);
    expect(users.user, isNull);
    await session.dispose();
  });

  test('SessionUser.numericId falls back to 0 for non-numeric ids', () {
    expect(const SessionUser(id: 'abc').numericId, 0);
    expect(const SessionUser(id: '4098').numericId, 4098);
  });
}
