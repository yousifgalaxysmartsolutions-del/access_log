import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../config/biometric_lock_config.dart';
import 'session_manager.dart';

abstract interface class DeviceBiometrics {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
  Future<void> cancel();
}

class LocalDeviceBiometrics implements DeviceBiometrics {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async =>
      await _auth.canCheckBiometrics &&
      (await _auth.getAvailableBiometrics()).isNotEmpty;

  @override
  Future<bool> authenticate(String reason) => _auth.authenticate(
    localizedReason: reason,
    biometricOnly: true,
    persistAcrossBackgrounding: false,
  );

  @override
  Future<void> cancel() async {
    await _auth.stopAuthentication();
  }
}

enum BiometricLockError { unavailable, notVerified }

/// Protects the in-memory UI on return from background, not the network/session.
/// No API calls, token writes, GPS/photo operations or background timers.
class BiometricResumeLock extends ChangeNotifier {
  BiometricResumeLock({
    required this.session,
    required this.biometrics,
    this.enabled = BiometricLockConfig.enabled,
    this.timeout = const Duration(
      minutes: BiometricLockConfig.backgroundTimeoutMinutes,
    ),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _generation = session.generation;
    _subscription = session.changes.listen((_) {
      if (!session.isAuthenticated || _generation != session.generation) {
        _generation = session.generation;
        _attempt++;
        _backgroundAt = null;
        locked = false;
        obscured = false;
        busy = false;
        error = null;
        unawaited(_cancel());
        _notify();
      }
    });
  }

  final SessionManager session;
  final DeviceBiometrics biometrics;
  final bool enabled;
  final Duration timeout;
  final DateTime Function() _now;
  late final StreamSubscription _subscription;
  late int _generation;
  DateTime? _backgroundAt;
  bool _foreground = true;
  bool _disposed = false;
  int _attempt = 0;
  bool locked = false;
  bool obscured = false;
  bool busy = false;
  BiometricLockError? error;

  bool get blocksContent =>
      enabled && session.isAuthenticated && (locked || obscured);

  /// Inactive can just mean a permission/biometric dialog, not background time.
  void inactive() {
    if (!enabled || !session.isAuthenticated) return;
    obscured = true;
    _notify();
  }

  void background() {
    _foreground = false;
    if (!enabled || !session.isAuthenticated) return;
    _backgroundAt ??= _now();
    obscured = true;
    _notify();
  }

  /// Returns true only when a new verification should be offered automatically.
  bool resume() {
    _foreground = true;
    if (!enabled || !session.isAuthenticated) return false;
    final since = _backgroundAt;
    final shouldLock = since != null && _now().difference(since) >= timeout;
    _backgroundAt = null;
    final newlyLocked = shouldLock && !locked;
    if (shouldLock) locked = true;
    obscured = false;
    _notify();
    return newlyLocked;
  }

  Future<void> unlock(String reason) async {
    if (_disposed ||
        !locked ||
        busy ||
        !_foreground ||
        !session.isAuthenticated) {
      return;
    }
    final attempt = ++_attempt;
    final generation = session.generation;
    busy = true;
    error = null;
    _notify();
    try {
      final available = await biometrics.isAvailable();
      if (!_current(attempt, generation)) return;
      if (!available) {
        error = BiometricLockError.unavailable;
        return;
      }
      final verified = await biometrics.authenticate(reason);
      if (!_current(attempt, generation)) return;
      if (verified && _foreground) {
        locked = false;
        obscured = false;
        _backgroundAt = null;
      } else {
        error = BiometricLockError.notVerified;
      }
    } catch (_) {
      if (_current(attempt, generation)) error = BiometricLockError.notVerified;
    } finally {
      if (_current(attempt, generation)) {
        busy = false;
        _notify();
      }
    }
  }

  bool _current(int attempt, int generation) =>
      !_disposed &&
      attempt == _attempt &&
      generation == session.generation &&
      session.isAuthenticated;

  /// Explicit fallback, never a silent unlock or stored-password replay.
  Future<void> signInAgain() async {
    _attempt++;
    busy = false;
    await _cancel();
    if (!_disposed) await session.logout();
  }

  Future<void> _cancel() async {
    try {
      await biometrics.cancel();
    } catch (_) {
      /* Platform may be unavailable. */
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    unawaited(_subscription.cancel());
    unawaited(_cancel());
    super.dispose();
  }
}
