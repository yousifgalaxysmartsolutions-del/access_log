import 'dart:async';

import 'package:access_log_plus/core/session/biometric_resume_lock.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/features/app_requirements/presentation/biometric_resume_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/periodic_photo_fakes.dart' show MemoryTokenStorage;

class _Biometrics implements DeviceBiometrics {
  bool available = true;
  bool verified = true;
  bool throws = false;
  int calls = 0;
  Completer<bool>? pending;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    if (throws) throw StateError('system cancelled');
    return pending?.future ?? verified;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  late DateTime now;
  late SessionManager session;
  late _Biometrics biometrics;
  late BiometricResumeLock lock;
  setUp(() {
    now = DateTime(2026, 10, 21, 10);
    session = SessionManager(MemoryTokenStorage())..startDemo();
    biometrics = _Biometrics();
    lock = BiometricResumeLock(
      session: session,
      biometrics: biometrics,
      enabled: true,
      timeout: const Duration(minutes: 5),
      now: () => now,
    );
  });
  tearDown(() async {
    lock.dispose();
    await session.dispose();
  });

  void returnAfter(Duration duration) {
    lock.background();
    now = now.add(duration);
    lock.resume();
  }

  test(
    'fresh sign-in is not blocked; short return opens without biometrics',
    () {
      expect(lock.blocksContent, false);
      returnAfter(const Duration(minutes: 4, seconds: 59));
      expect(lock.blocksContent, false);
      expect(biometrics.calls, 0);
    },
  );

  test(
    'exactly five minutes requires verification, leaving session untouched',
    () async {
      final generation = session.generation;
      returnAfter(const Duration(minutes: 5));
      expect(lock.locked, true);
      expect(session.isAuthenticated, true);
      await lock.unlock('Unlock');
      expect(lock.blocksContent, false);
      expect(session.generation, generation);
    },
  );

  test('disabled configuration never prompts or blocks', () async {
    final disabled = BiometricResumeLock(
      session: session,
      biometrics: biometrics,
      enabled: false,
      now: () => now,
    );
    disabled.background();
    now = now.add(const Duration(days: 1));
    disabled.resume();
    await disabled.unlock('Unlock');
    expect(disabled.blocksContent, false);
    expect(biometrics.calls, 0);
    disabled.dispose();
  });

  test('custom duration is respected; inactive alone never starts timeout', () {
    lock.inactive();
    now = now.add(const Duration(hours: 1));
    lock.resume();
    expect(lock.locked, false);
    final custom = BiometricResumeLock(
      session: session,
      biometrics: biometrics,
      enabled: true,
      timeout: const Duration(minutes: 1),
      now: () => now,
    );
    custom.background();
    now = now.add(const Duration(minutes: 1));
    expect(custom.resume(), true);
    custom.dispose();
  });

  test('repeated lifecycle messages do not reset the original timestamp', () {
    lock.background();
    now = now.add(const Duration(minutes: 4));
    lock.background();
    now = now.add(const Duration(minutes: 1));
    expect(lock.resume(), true);
    expect(lock.resume(), false);
    expect(lock.locked, true);
  });

  test(
    'cancelled or failed verification keeps lock and allows retry',
    () async {
      returnAfter(const Duration(minutes: 5));
      biometrics.verified = false;
      await lock.unlock('Unlock');
      expect(lock.locked, true);
      expect(lock.error, BiometricLockError.notVerified);
      biometrics.throws = true;
      await lock.unlock('Unlock');
      expect(lock.locked, true);
      expect(lock.busy, false);
      biometrics.throws = false;
      biometrics.verified = true;
      await lock.unlock('Unlock');
      expect(lock.locked, false);
    },
  );

  test('no enrolled biometrics never silently unlocks', () async {
    returnAfter(const Duration(minutes: 5));
    biometrics.available = false;
    await lock.unlock('Unlock');
    expect(lock.error, BiometricLockError.unavailable);
    expect(lock.locked, true);
    expect(biometrics.calls, 0);
    await lock.signInAgain();
    expect(session.isAuthenticated, false);
    expect(lock.blocksContent, false);
  });

  test(
    'duplicate attempts are single-flight and stale user results are ignored',
    () async {
      returnAfter(const Duration(minutes: 5));
      biometrics.pending = Completer<bool>();
      final attempt = lock.unlock('Unlock');
      await Future<void>.delayed(Duration.zero);
      await lock.unlock('Unlock');
      expect(biometrics.calls, 1);
      await session.logout();
      session.startDemo();
      await Future<void>.delayed(Duration.zero);
      returnAfter(const Duration(minutes: 5));
      biometrics.pending!.complete(true);
      await attempt;
      expect(
        lock.locked,
        true,
        reason: 'old account cannot unlock a new account',
      );
    },
  );

  test('success arriving in background must not unlock', () async {
    returnAfter(const Duration(minutes: 5));
    biometrics.pending = Completer<bool>();
    final attempt = lock.unlock('Unlock');
    await Future<void>.delayed(Duration.zero);
    lock.background();
    biometrics.pending!.complete(true);
    await attempt;
    expect(lock.locked, true);
    lock.resume();
    expect(lock.locked, true);
  });

  for (final language in ['en', 'ar']) {
    testWidgets('lock UI supports $language, small screen and large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      biometrics.available = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: BiometricResumeGuard(controller: lock, child: child!),
          ),
          home: const Scaffold(body: Text('PRIVATE INCIDENT DATA')),
        ),
      );
      lock.background();
      now = now.add(const Duration(minutes: 5));
      lock.resume();
      await lock.unlock('Unlock');
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'ar' ? 'التطبيق مقفول' : 'App locked'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      final tree = tester
          .getSemantics(find.byType(BiometricResumeGuard))
          .toStringDeep();
      expect(tree, isNot(contains('PRIVATE INCIDENT DATA')));
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'real lifecycle triggers one prompt and hardware back cannot bypass lock',
    (tester) async {
      biometrics.verified = false;
      final navigator = GlobalKey<NavigatorState>();
      final routes = BiometricLockRouteObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [routes],
          builder: (context, child) => BiometricResumeGuard(
            controller: lock,
            routeObserver: routes,
            child: child!,
          ),
          home: const Scaffold(body: Text('Base route')),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Route preserved')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(lock.locked, true);
      expect(biometrics.calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(lock.locked, true);
      expect(find.text('Route preserved'), findsOneWidget);
      biometrics.verified = true;
      await lock.unlock('Unlock');
      await tester.pumpAndSettle();
      expect(find.text('App locked'), findsNothing);
      expect(find.text('Route preserved'), findsOneWidget);
      expect(await navigator.currentState!.maybePop(), true);
      await tester.pumpAndSettle();
      expect(find.text('Base route'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
