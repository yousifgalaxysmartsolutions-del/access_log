import 'dart:async';
import '../storage/secure_storage_service.dart';

enum SessionStatus { signedOut, authenticated, expired }

class SessionManager {
  SessionManager(this.storage);
  final TokenStorage storage;
  final _changes = StreamController<SessionStatus>.broadcast();
  Stream<SessionStatus> get changes => _changes.stream;
  SessionStatus status = SessionStatus.signedOut;
  SessionTokens? tokens;
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
    status = tokens == null
        ? SessionStatus.signedOut
        : SessionStatus.authenticated;
  }

  Future<void> signIn(SessionTokens value, {bool remember = true}) async {
    final epoch = ++generation;
    _remember = remember;
    await _serialize(
      () => remember ? storage.writeTokens(value) : storage.clear(),
    );
    if (epoch != generation) return;
    tokens = value;
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
    tokens = value;
    return true;
  }

  void startDemo() {
    generation++;
    tokens = null;
    status = SessionStatus.authenticated;
    _changes.add(status);
  }

  Future<void> logout({bool expired = false}) async {
    generation++;
    tokens = null;
    status = expired ? SessionStatus.expired : SessionStatus.signedOut;
    _changes.add(status);
    await _serialize(storage.clear);
  }

  Future<void> dispose() => _changes.close();
}
