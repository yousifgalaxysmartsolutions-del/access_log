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

  Future<void> _serialize(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> restore() async {
    tokens = await storage.readTokens();
    user = await users?.readUser();
    status = tokens == null
        ? SessionStatus.signedOut
        : SessionStatus.authenticated;
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
