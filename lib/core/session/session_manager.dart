import 'dart:async';
import '../storage/secure_storage_service.dart';

enum SessionStatus { signedOut, authenticated, expired }

class SessionManager {
  SessionManager(this.storage, [this.users]);
  final TokenStorage storage;

  /// Optional so existing callers and test doubles keep working. Without it the
  /// session stays memory-only for the user identity.
  final SessionUserStorage? users;
  final _changes = StreamController<SessionStatus>.broadcast();
  Stream<SessionStatus> get changes => _changes.stream;
  SessionStatus status = SessionStatus.signedOut;
  SessionTokens? tokens;

  /// Identity of the signed-in user, used by the CAP request envelope.
  SessionUser? user;
  int get userId => user?.numericId ?? 0;
  int generation = 0;
  bool _remember = true;
  Future<void> _writes = Future.value();
  bool get isAuthenticated => status == SessionStatus.authenticated;
  DateTime Function() now = DateTime.now;
  Future<void>? _refreshing;
  int? _refreshEpoch;
  Future<void>? _restoring;

  Future<void> ensureFresh(
    Future<SessionTokens> Function(String) refresh, {
    bool force = false,
  }) async {
    final epoch = generation;
    if (_refreshEpoch == epoch && _refreshing != null) return _refreshing!;
    if (!isAuthenticated || tokens == null) {
      throw const FormatException('No session');
    }
    if (!force && !tokens!.needsRefresh(now())) return;
    _refreshEpoch = epoch;
    final running = _refreshing = _refresh(refresh, epoch);
    try {
      await running;
    } finally {
      if (identical(_refreshing, running)) {
        _refreshing = null;
        _refreshEpoch = null;
      }
    }
  }

  Future<void> _refresh(
    Future<SessionTokens> Function(String) refresh,
    int epoch,
  ) async {
    try {
      final current = tokens!;
      if (!current.canRefresh(now())) {
        throw const FormatException('Refresh unavailable');
      }
      final value = await refresh(current.refreshToken);
      if (!value.canRefresh(now()) ||
          value.accessToken.trim().isEmpty ||
          value.accessTokenExpiresAtUtc == null ||
          !value.accessTokenExpiresAtUtc!.isAfter(now().toUtc())) {
        throw const FormatException('Invalid refreshed credentials');
      }
      if (!await rotate(value, epoch)) {
        throw const FormatException('Session changed');
      }
    } catch (_) {
      if (epoch == generation) await logout(expired: true);
      rethrow;
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> restore({
    Future<SessionTokens> Function(String)? refresh,
  }) async {
    final running = _restoring ??= _restore(refresh);
    try {
      await running;
    } finally {
      if (identical(_restoring, running)) _restoring = null;
    }
  }

  Future<void> _restore(Future<SessionTokens> Function(String)? refresh) async {
    final epoch = generation;
    try {
      var value = await storage.readTokens();
      final identity = await users?.readUser();
      if (epoch != generation) return;
      if (value == null || !value.canRefresh(now())) {
        await logout();
        return;
      }
      if (value.needsRefresh(now())) {
        if (refresh == null) throw const FormatException('Refresh unavailable');
        value = await refresh(value.refreshToken);
        if (!value.canRefresh(now()) ||
            value.accessToken.trim().isEmpty ||
            value.accessTokenExpiresAtUtc == null ||
            !value.accessTokenExpiresAtUtc!.isAfter(now().toUtc())) {
          throw const FormatException('Invalid restored credentials');
        }
      }
      final restored = value;
      await _serialize(() async {
        if (epoch == generation) await storage.writeTokens(restored);
      });
      if (epoch != generation) return;
      tokens = restored;
      user = identity;
      status = SessionStatus.authenticated;
    } catch (_) {
      if (epoch == generation) await logout(expired: true);
    }
  }

  Future<void> signIn(
    SessionTokens value, {
    SessionUser? user,
    bool remember = true,
  }) async {
    final epoch = ++generation;
    _remember = remember;
    await _serialize(() async {
      if (remember) {
        await storage.writeTokens(value);
        await _writeUser(user);
      } else {
        await storage.clear();
        await users?.clearUser();
      }
    });
    if (epoch != generation) return;
    tokens = value;
    this.user = user;
    status = SessionStatus.authenticated;
    _changes.add(status);
  }

  Future<bool> rotate(SessionTokens value, int epoch) async {
    if (epoch != generation || !isAuthenticated) return false;
    await _serialize(() async {
      if (epoch == generation && isAuthenticated && _remember) {
        await storage.writeTokens(value);
      }
    });
    if (epoch != generation || !isAuthenticated) return false;
    // The user identity is deliberately untouched: rotation only replaces
    // credentials, never who they belong to.
    tokens = value;
    return true;
  }

  Future<void> _writeUser(SessionUser? value) async {
    final target = users;
    if (target == null) return;
    if (value == null) {
      await target.clearUser();
    } else {
      await target.writeUser(value);
    }
  }

  void startDemo() {
    generation++;
    tokens = null;
    user = null;
    status = SessionStatus.authenticated;
    _changes.add(status);
  }

  Future<void> logout({bool expired = false}) async {
    generation++;
    tokens = null;
    user = null;
    status = expired ? SessionStatus.expired : SessionStatus.signedOut;
    _changes.add(status);
    await _serialize(() async {
      await storage.clear();
      await users?.clearUser();
    });
  }

  Future<void> dispose() => _changes.close();
}
