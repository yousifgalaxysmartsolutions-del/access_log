import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/periodic_photo/data/periodic_photo_schedule_store.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_coordinator.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_schedule.dart';

import 'support/periodic_photo_fakes.dart';

/// Timing/configuration policy of the periodic photo requirement.
///
/// The deadline is always absolute and persisted: a restart, a background
/// period or a reconcile must never restart the interval, and the configured
/// interval is the only source of cadence.
void main() {
  late FakeSystemConfigurationRepository configuration;
  late MemoryScheduleStore store;
  late DateTime now;
  late PeriodicPhotoCoordinator coordinator;

  setUp(() {
    configuration = FakeSystemConfigurationRepository(
      initial: photoConfiguration(photoEnabled: false),
    );
    store = MemoryScheduleStore();
    now = DateTime(2026, 1, 1, 10, 0, 0);
    coordinator = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: store,
      now: () => now,
    );
  });

  tearDown(() async {
    await coordinator.dispose();
  });

  test('enablePhotoCapture = false → no periodic requirement at all',
      () async {
    configuration.result = Success(photoConfiguration(photoEnabled: false));

    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.disabled);
    expect(coordinator.snapshot.nextPhotoDueAt, isNull);
    // Nothing was ever scheduled, so no deadline can be pending either.
    expect(store.value, isNull);
  });

  test('requirement becomes due after the configured interval', () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );

    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
      reason: 'entered at 10:00 with a 1 minute interval → due at 10:01',
    );

    now = DateTime(2026, 1, 1, 10, 1, 0);
    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.due);
  });

  test('interval comes dynamically from configuration, never a constant',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 5),
    );
    await coordinator.reconcile();
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 5, 0),
    );
    await coordinator.dispose();

    // A different configured value produces a different schedule — the cadence
    // is never a constant in code.
    final otherStore = MemoryScheduleStore();
    final other = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: otherStore,
      now: () => now,
    );
    addTearDown(other.dispose);
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 30),
    );

    await other.reconcile();

    expect(
      other.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 30, 0),
    );
  });

  test('app restart does not restart the interval (deadline preserved)',
      () async {
    final directory = await Directory.systemTemp.createTemp('cap_photo_test');
    addTearDown(() => directory.delete(recursive: true));
    final realStore = PeriodicPhotoScheduleStore(
      directory: () async => directory,
    );
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );

    final first = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: realStore,
      now: () => now,
    );
    await first.reconcile();
    expect(
      first.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );
    await first.dispose();

    // Relaunched 30 seconds later: the deadline stays 10:01, not 10:01:30.
    now = DateTime(2026, 1, 1, 10, 0, 30);
    final second = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: realStore,
      now: () => now,
    );
    addTearDown(second.dispose);

    await second.reconcile();

    expect(second.snapshot.state, PeriodicPhotoScheduleState.waiting);
    expect(
      second.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
      reason: 'a process restart must not restart the interval',
    );
  });

  test('deadline reached in the background → one overdue requirement on resume',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);

    final emissions = <PeriodicPhotoSnapshot>[];
    final subscription = coordinator.changes.listen(emissions.add);

    // Five intervals elapsed while backgrounded: one deadline, five missed
    // windows — still exactly ONE overdue requirement, never a stack of them.
    now = DateTime(2026, 1, 1, 10, 5, 0);
    await coordinator.reconcile(); // AppLifecycleState.resumed

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.due);
    expect(
      emissions.where((s) => s.state == PeriodicPhotoScheduleState.due),
      hasLength(1),
      reason: 'multiple missed intervals must not stack requirements',
    );

    // Further reconciles while overdue never re-emit or re-schedule.
    await coordinator.reconcile();
    await coordinator.reconcile();
    expect(emissions, hasLength(1));
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.due);
    await subscription.cancel();
  });

  test('foreground: the armed timer reaches the deadline by itself', () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    // A deadline a few milliseconds away, with a matching persisted interval,
    // so the coordinator arms a real wake-up timer instead of re-deriving.
    store.value = PeriodicPhotoSchedule(
      nextPhotoDueAt: now.add(const Duration(milliseconds: 60)),
      intervalMinutes: 1,
    );

    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);
    final loadsAfterArm = configuration.loads;

    now = store.value!.nextPhotoDueAt!;
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(
      coordinator.snapshot.state,
      PeriodicPhotoScheduleState.due,
      reason: 'the deadline must activate the requirement without any trigger',
    );
    expect(
      configuration.loads,
      loadsAfterArm,
      reason: 'reaching the deadline is not a configuration refresh',
    );
  });

  test('configuration false while scheduled → requirement cancelled',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);

    configuration.result = Success(photoConfiguration(photoEnabled: false));
    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.disabled);

    // Long past the old deadline, still disabled: nothing keeps demanding.
    now = DateTime(2026, 1, 1, 10, 30, 0);
    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.disabled);
    expect(coordinator.snapshot.nextPhotoDueAt, isNull);
  });

  test('configuration back to true → schedule resumes without a fresh window',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    await coordinator.reconcile();
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );

    configuration.result = Success(photoConfiguration(photoEnabled: false));
    await coordinator.reconcile();

    // Re-enabled after the deadline passed: the requirement stays owed instead
    // of silently getting a brand-new interval.
    now = DateTime(2026, 1, 1, 10, 5, 0);
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.due);
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );
  });

  test('interval change → schedule reconciled cleanly', () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 5),
    );
    await coordinator.reconcile();
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 5, 0),
    );

    // Backend shortens 5 → 2 while no photo is taken yet: the deadline pulls
    // in, and being already overdue keeps it overdue.
    now = DateTime(2026, 1, 1, 10, 3, 0);
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 2),
    );
    await coordinator.reconcile();

    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 2, 0),
    );
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.due);
  });

  test('interval change after a completed photo anchors on the completion',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 2),
    );
    await coordinator.reconcile();
    now = DateTime(2026, 1, 1, 10, 1, 20);
    await coordinator.reconcile(); // due
    await coordinator.markCompleted();
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 3, 20),
      reason: 'next due = completion (10:01:20) + configured interval',
    );

    // 2 → 5: the next window recomputes from the same completion moment.
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 5),
    );
    await coordinator.reconcile();
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 6, 20),
    );
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);
  });

  test('duplicate reconcile → single-flight, one live timer, no periodic one',
      () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    final activeTimers = <Timer>{};
    var periodicTimers = 0;

    Timer tracked(Timer inner) {
      late final _TrackedTimer trackedTimer;
      trackedTimer = _TrackedTimer(inner, () => activeTimers.remove(trackedTimer));
      activeTimers.add(trackedTimer);
      return trackedTimer;
    }

    await runZoned(
      () async {
        await Future.wait([
          coordinator.reconcile(),
          coordinator.reconcile(),
          coordinator.reconcile(),
          coordinator.reconcile(),
          coordinator.reconcile(),
        ]);
        // Concurrent calls share runs instead of loading per call.
        expect(
          configuration.loads,
          lessThan(5),
          reason: 'concurrent reconciles must share runs',
        );
        // More reconciles re-arm the wake timer; they must never stack.
        for (var i = 0; i < 3; i++) {
          await coordinator.reconcile();
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, f) =>
            tracked(parent.createTimer(zone, duration, f)),
        createPeriodicTimer: (self, parent, zone, duration, f) {
          periodicTimers++;
          return parent.createPeriodicTimer(zone, duration, f);
        },
      ),
    );

    expect(periodicTimers, 0, reason: 'no Timer.periodic anywhere');
    expect(
      activeTimers,
      hasLength(1),
      reason: 'duplicate reconciles must re-arm the single wake timer, '
          'never stack timers',
    );
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );
  });

  test('configuration load failure keeps the last known state', () async {
    configuration.result = Success(
      photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    await coordinator.reconcile();
    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);

    configuration.result = const FailureResult(NetworkFailure());
    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.waiting);
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );
  });

  test('first-ever load failure derives nothing (no invented requirement)',
      () async {
    configuration.result = const FailureResult(NetworkFailure());

    await coordinator.reconcile();

    expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.unknown);
    expect(coordinator.snapshot.isDue, isFalse);
  });
}

class _TrackedTimer implements Timer {
  _TrackedTimer(this._inner, this._onCancel);

  final Timer _inner;
  final void Function() _onCancel;
  bool _cancelled = false;

  @override
  bool get isActive => _inner.isActive;

  @override
  int get tick => _inner.tick;

  @override
  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _onCancel();
    }
    _inner.cancel();
  }
}
