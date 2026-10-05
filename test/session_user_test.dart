import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 4, 12);
  SessionTokens value({int accessSeconds = 3600, int refreshSeconds = 86400}) =>
      SessionTokens(
        'access',
        'refresh',
        accessTokenExpiresAtUtc: now.add(Duration(seconds: accessSeconds)),
        refreshTokenExpiresAtUtc: now.add(Duration(seconds: refreshSeconds)),
      );

  test(
    'secure storage persists both tokens and UTC expiries in one record',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureStorageService();
      await storage.writeTokens(value());
      final read = await storage.readTokens();
      expect(read!.toJson(), value().toJson());
      await storage.clear();
      expect(await storage.readTokens(), isNull);
    },
  );

  test('startup valid access restores without refreshing', () async {
    final storage = _MemoryTokens()..tokens = value();
    final users = _MemoryUsers()..user = const SessionUser(id: '4098');
    final session = SessionManager(storage, users)..now = () => now;
    var count = 0;
    await session.restore(
      refresh: (_) async {
        count++;
        return value();
      },
    );
    expect(count, 0);
    expect(session.isAuthenticated, true);
    expect(session.userId, 4098);
    await session.dispose();
  });

  test(
    'concurrent startup near expiry refreshes once before authentication',
    () async {
      final storage = _MemoryTokens()..tokens = value(accessSeconds: 60);
      final users = _MemoryUsers()..user = const SessionUser(id: '4098');
      final session = SessionManager(storage, users)..now = () => now;
      final result = Completer<SessionTokens>();
      var count = 0;
      Future<SessionTokens> refresh(String token) {
        count++;
        expect(token, 'refresh');
        return result.future;
      }

      final a = session.restore(refresh: refresh);
      final b = session.restore(refresh: refresh);
      await Future<void>.delayed(Duration.zero);
      expect(session.isAuthenticated, false);
      expect(count, 1);
      final rotated = SessionTokens(
        'new',
        'rotated',
        accessTokenExpiresAtUtc: now.add(const Duration(hours: 1)),
        refreshTokenExpiresAtUtc: now.add(const Duration(days: 10)),
      );
      result.complete(rotated);
      await Future.wait([a, b]);
      expect(storage.tokens, same(rotated));
      expect(session.tokens, same(rotated));
      expect(session.userId, 4098);
      expect(session.isAuthenticated, true);
      await session.dispose();
    },
  );

  test(
    'startup absent expired or legacy credentials clear stale state',
    () async {
      for (final token in [
        null,
        value(refreshSeconds: 0),
        const SessionTokens('a', ''),
        const SessionTokens('a', 'r'),
      ]) {
        final storage = _MemoryTokens()..tokens = token;
        final users = _MemoryUsers()..user = const SessionUser(id: '4098');
        final session = SessionManager(storage, users)..now = () => now;
        var count = 0;
        await session.restore(
          refresh: (_) async {
            count++;
            return value();
          },
        );
        expect(count, 0);
        expect(session.isAuthenticated, false);
        expect(storage.tokens, isNull);
        expect(users.user, isNull);
        await session.dispose();
      }
    },
  );

  test(
    'logout during startup refresh cannot resurrect persisted session',
    () async {
      final storage = _MemoryTokens()..tokens = value(accessSeconds: -1);
      final session = SessionManager(storage)..now = () => now;
      final pending = Completer<SessionTokens>();
      final started = Completer<void>();
      final restoring = session.restore(
        refresh: (_) {
          started.complete();
          return pending.future;
        },
      );
      await started.future;
      await session.logout();
      pending.complete(value());
      await restoring;
      expect(session.isAuthenticated, false);
      expect(storage.tokens, isNull);
      await session.dispose();
    },
  );

  test(
    'UTC offset response normalizes expiry and rejects invalid credentials',
    () {
      final token = SessionTokens.fromResponse(
        access: 'a',
        refresh: 'r',
        lifetime: 3600,
        refreshExpiry: '2026-10-11T14:34:28.0422592+03:00',
        now: now,
      );
      expect(token.accessTokenExpiresAtUtc, now.add(const Duration(hours: 1)));
      expect(token.refreshTokenExpiresAtUtc!.hour, 11);
      expect(token.refreshTokenExpiresAtUtc!.isUtc, true);
      for (final expiry in [
        null,
        'invalid',
        '2020-01-01T00:00:00Z',
        '2026-10-11T14:34:28',
      ]) {
        expect(
          () => SessionTokens.fromResponse(
            access: 'a',
            refresh: 'r',
            lifetime: 3600,
            refreshExpiry: expiry,
            now: now,
          ),
          throwsFormatException,
        );
      }
      for (final lifetime in [null, 0, -1]) {
        expect(
          () => SessionTokens.fromResponse(
            access: 'a',
            refresh: 'r',
            lifetime: lifetime,
            refreshExpiry: '2026-10-11T14:34:28Z',
            now: now,
          ),
          throwsFormatException,
        );
      }
    },
  );
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
    final tokens = _MemoryTokens()
      ..tokens = SessionTokens(
        'a',
        'r',
        accessTokenExpiresAtUtc: DateTime.now().toUtc().add(
          const Duration(hours: 1),
        ),
        refreshTokenExpiresAtUtc: DateTime.now().toUtc().add(
          const Duration(days: 7),
        ),
      );
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
