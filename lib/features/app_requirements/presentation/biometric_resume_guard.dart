import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/session/biometric_resume_lock.dart';
import '../../../core/session/session_manager.dart';
import '../../../widgets/app_button.dart';

class _LockPopEntry extends PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
}

/// Protect the actual top route, including Android predictive back. A PopScope
/// above MaterialApp's navigator would have no enclosing ModalRoute to protect.
class BiometricLockRouteObserver extends NavigatorObserver {
  final _entry = _LockPopEntry();
  ModalRoute<dynamic>? _top;

  void setBlocked(bool value) => _entry.canPopNotifier.value = !value;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _top?.unregisterPopEntry(_entry);
    _top = topRoute is ModalRoute<dynamic> ? topRoute : null;
    _top?.registerPopEntry(_entry);
  }
}

/// Sits above the existing GPS/photo guard. Its route stays mounted and its
/// background work keeps running, but private content cannot receive focus,
/// pointer events or accessibility traversal while locked.
class BiometricResumeGuard extends StatefulWidget {
  const BiometricResumeGuard({
    super.key,
    required this.child,
    this.controller,
    this.routeObserver,
  });
  final Widget child;
  final BiometricResumeLock? controller;
  final BiometricLockRouteObserver? routeObserver;

  @override
  State<BiometricResumeGuard> createState() => _BiometricResumeGuardState();
}

class _BiometricResumeGuardState extends State<BiometricResumeGuard>
    with WidgetsBindingObserver {
  BiometricResumeLock? _lock;
  bool _ownsLock = false;

  @override
  void initState() {
    super.initState();
    _lock = widget.controller;
    if (_lock == null && services.isRegistered<SessionManager>()) {
      _lock = BiometricResumeLock(
        session: services<SessionManager>(),
        biometrics: LocalDeviceBiometrics(),
      );
      _ownsLock = true;
    }
    _lock?.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    widget.routeObserver?.setBlocked(_lock?.blocksContent ?? false);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        _lock?.inactive();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lock?.background();
      case AppLifecycleState.resumed:
        if (_lock?.resume() == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _unlock();
          });
        }
    }
  }

  @override
  Future<bool> didPopRoute() async => _lock?.blocksContent ?? false;

  void _unlock() => unawaited(
    _lock!.unlock(
      context.tr(
        'Verify your identity to return to Access Log+',
        'أكّد هويتك للعودة إلى Access Log+',
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock?.removeListener(_changed);
    if (_ownsLock) _lock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = _lock;
    if (lock == null) return widget.child;
    final blocking = lock.blocksContent;
    widget.routeObserver?.setBlocked(blocking);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: blocking,
          child: IgnorePointer(
            ignoring: blocking,
            child: ExcludeFocus(excluding: blocking, child: widget.child),
          ),
        ),
        if (blocking)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: !lock.locked
                  ? const Center(child: Icon(Icons.lock_outline, size: 48))
                  : SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  size: 76,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  context.tr('App locked', 'التطبيق مقفول'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr(
                                    'Verify your identity to continue where you left off.',
                                    'أكّد هويتك لمتابعة العمل من حيث توقفت.',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (lock.error != null) ...[
                                  const SizedBox(height: 16),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      lock.error ==
                                              BiometricLockError.unavailable
                                          ? context.tr(
                                              'Biometrics are not set up or available. Sign in again to continue.',
                                              'البصمة غير متاحة أو غير مُعدّة على الجهاز. سجّل الدخول مجددًا للمتابعة.',
                                            )
                                          : context.tr(
                                              'Verification was not completed. Try again or sign in again.',
                                              'لم يكتمل التحقق. حاول مجددًا أو سجّل الدخول مرة أخرى.',
                                            ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                AppButton(
                                  label: context.tr(
                                    'Unlock with biometrics',
                                    'فتح التطبيق بالبصمة',
                                  ),
                                  icon: Icons.fingerprint,
                                  expanded: true,
                                  loading: lock.busy,
                                  onPressed: _unlock,
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  label: context.tr(
                                    'Sign in again',
                                    'تسجيل الدخول مجددًا',
                                  ),
                                  style: AppButtonStyle.outline,
                                  expanded: true,
                                  onPressed: lock.busy
                                      ? null
                                      : () => unawaited(lock.signInAgain()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
