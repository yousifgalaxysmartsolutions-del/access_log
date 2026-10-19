import 'dart:async';

import '../../../core/network/result.dart';
import '../../incidents/domain/repositories/system_gps_configuration_repository.dart';
import 'periodic_photo_schedule.dart';
import '../data/periodic_photo_schedule_store.dart';

/// Whether the periodic photo requirement is currently derivable.
enum PeriodicPhotoScheduleState {
  /// No configuration has been loaded yet (or every attempt failed before one
  /// ever succeeded). No requirement is derived.
  unknown,

  /// Configuration is known and the requirement is switched off (or has no
  /// usable interval).
  disabled,

  /// A deadline exists and has not been reached yet.
  waiting,

  /// The deadline has been reached: one photo is required.
  due,
}

/// Immutable view of the timing policy at one point in time.
class PeriodicPhotoSnapshot {
  const PeriodicPhotoSnapshot({
    this.state = PeriodicPhotoScheduleState.unknown,
    this.nextPhotoDueAt,
    this.intervalMinutes,
  });

  final PeriodicPhotoScheduleState state;
  final DateTime? nextPhotoDueAt;
  final int? intervalMinutes;

  bool get isDue => state == PeriodicPhotoScheduleState.due;

  @override
  bool operator ==(Object other) =>
      other is PeriodicPhotoSnapshot &&
      other.state == state &&
      other.nextPhotoDueAt == nextPhotoDueAt &&
      other.intervalMinutes == intervalMinutes;

  @override
  int get hashCode => Object.hash(state, nextPhotoDueAt, intervalMinutes);
}

/// Owns the *timing and configuration policy* of the periodic photo
/// requirement. It deliberately owns no camera, no UI and no networking.
///
/// ```text
/// SystemGpsConfiguration (GetSystemConfiguration)
///         ↓
/// PeriodicPhotoCoordinator      → nextPhotoDueAt (persisted)
///         ↓
/// PeriodicPhotoGate             → blocking state + user intents
///         ↓
/// AppRequirementGuard           → the single root overlay
/// ```
///
/// Rules enforced here:
/// * the interval always comes from configuration — never a hardcoded minute;
/// * nothing is scheduled before the current requirement is validly completed
///   ([markCompleted] is the only way the deadline moves forward);
/// * the deadline is persisted, so a Flutter restart does not restart the
///   interval;
/// * `enablePhotoCapture == false` cancels the requirement entirely;
/// * exactly one timer exists, and it only *wakes* a re-evaluation — due-ness
///   is always derived from the deadline vs. the current time, so several
///   missed intervals collapse into a single overdue requirement instead of a
///   stack of missed-photo dialogs.
///
/// There is no `Timer.periodic` anywhere: a one-shot timer is armed to the exact
/// deadline and only by this coordinator.
class PeriodicPhotoCoordinator {
  PeriodicPhotoCoordinator({
    required SystemGpsConfigurationRepository configuration,
    required PeriodicPhotoScheduleStore store,
    DateTime Function()? now,
  }) : _configuration = configuration,
       _store = store,
       _now = now ?? DateTime.now;

  final SystemGpsConfigurationRepository _configuration;
  final PeriodicPhotoScheduleStore _store;
  final DateTime Function() _now;

  final _changes = StreamController<PeriodicPhotoSnapshot>.broadcast();

  /// Timing-state changes, for the gate to render.
  Stream<PeriodicPhotoSnapshot> get changes => _changes.stream;

  PeriodicPhotoSnapshot _snapshot = const PeriodicPhotoSnapshot();
  PeriodicPhotoSnapshot get snapshot => _snapshot;

  PeriodicPhotoSchedule _schedule = const PeriodicPhotoSchedule();
  bool _scheduleLoaded = false;
  bool _configurationLoaded = false;
  bool _configurationEnabled = false;
  int? _intervalMinutes;

  Future<void>? _reconciling;
  bool _pendingReconcile = false;
  Timer? _timer;

  /// Reconciles the timing policy with the system configuration.
  ///
  /// Called on cold start, authenticated session, configuration refresh, app
  /// resume and from the deadline timer. Concurrent calls share one run and a
  /// call that arrives mid-run requests exactly one follow-up pass. Never
  /// periodic: nothing here polls `GetSystemConfiguration`.
  Future<void> reconcile() {
    final active = _reconciling;
    if (active != null) {
      _pendingReconcile = true;
      return active;
    }
    final started = _run();
    _reconciling = started;
    return started.whenComplete(() {
      if (identical(_reconciling, started)) _reconciling = null;
      if (_pendingReconcile) {
        _pendingReconcile = false;
        unawaited(reconcile());
      }
    });
  }

  Future<void> _run() async {
    final result = await _configuration.load();
    switch (result) {
      case FailureResult():
        // A refresh failure neither creates nor cancels a requirement: the last
        // known configuration keeps applying, and a first-ever failure simply
        // derives nothing. Never an extra blocking screen caused by a failed
        // read.
        _emit();
      case Success(:final data):
        _configurationLoaded = true;
        _configurationEnabled = data.requiresPeriodicPhoto;
        _intervalMinutes = data.periodicPhotoCaptureIntervalMinutes;
        if (!_configurationEnabled) {
          // Cancel future requirements but keep the persisted history, so
          // re-enabling later resumes instead of starting from nothing.
          _stopTimer();
          _emit();
          return;
        }
        await _ensureSchedule();
    }
  }

  /// Makes sure a deadline exists for the current interval, then arms the timer.
  ///
  /// A persisted deadline with an unchanged interval is honoured as-is (this is
  /// what keeps a restart from restarting the interval). It is only recomputed
  /// when there is none yet or the configured interval changed.
  Future<void> _ensureSchedule() async {
    final interval = _intervalMinutes;
    if (interval == null) {
      _emit();
      return;
    }
    if (!_scheduleLoaded) {
      _schedule = await _store.read() ?? const PeriodicPhotoSchedule();
      _scheduleLoaded = true;
    }
    if (_schedule.nextPhotoDueAt == null ||
        _schedule.intervalMinutes != interval) {
      _schedule = _derive(schedule: _schedule, now: _now(), interval: interval);
      await _persist();
    }
    _arm();
    _emit();
  }

  /// Computes a deadline for the current interval.
  ///
  /// * A completed photo anchors on the moment it was completed, so the next
  ///   requirement is exactly one interval after it (no overlapping windows).
  /// * With no photo yet but a previously scheduled window, the window start is
  ///   recovered from the persisted policy (`deadline - oldInterval`) and the
  ///   *new* interval is applied cleanly from that same anchor: a shortened
  ///   interval pulls the deadline in (5 → 2 on a 10:00 window → due 10:02), a
  ///   lengthened one pushes it out.
  /// * With nothing persisted at all, the very first window starts now.
  PeriodicPhotoSchedule _derive({
    required PeriodicPhotoSchedule schedule,
    required DateTime now,
    required int interval,
  }) {
    final duration = Duration(minutes: interval);
    final last = schedule.lastPeriodicPhotoAt;
    if (last != null) {
      return schedule.copyWith(
        nextPhotoDueAt: last.add(duration),
        intervalMinutes: interval,
      );
    }
    final persisted = schedule.nextPhotoDueAt;
    if (persisted == null) {
      return schedule.copyWith(
        nextPhotoDueAt: now.add(duration),
        intervalMinutes: interval,
      );
    }
    final oldInterval = schedule.intervalMinutes;
    if (oldInterval == null || oldInterval < 1) {
      // Deadline without a known policy: nothing sane to anchor on, so keep it.
      return schedule.copyWith(intervalMinutes: interval);
    }
    final anchor = persisted.subtract(Duration(minutes: oldInterval));
    return schedule.copyWith(
      nextPhotoDueAt: anchor.add(duration),
      intervalMinutes: interval,
    );
  }

  /// Records that the outstanding requirement was validly completed.
  ///
  /// This is the *only* place the deadline moves forward, so the next
  /// requirement is never scheduled before the current one is satisfied.
  Future<void> markCompleted() async {
    final interval = _intervalMinutes;
    if (interval == null) {
      _emit();
      return;
    }
    final now = _now();
    _schedule = PeriodicPhotoSchedule(
      lastPeriodicPhotoAt: now,
      nextPhotoDueAt: now.add(Duration(minutes: interval)),
      intervalMinutes: interval,
    );
    // Persisted best-effort: CAP already accepted the photo, so a failed local
    // write must not leave the gate stuck in `submitting` or re-ask the user
    // for a photo the server confirmed.
    await _persist();
    _arm();
    _emit();
  }

  Future<void> _persist() async {
    try {
      await _store.write(_schedule);
    } on Exception {
      // The in-memory schedule stays authoritative for this session; a restart
      // then falls back to the last successfully written deadline.
    }
  }

  /// Arms the single wake-up timer to the exact deadline.
  ///
  /// If the deadline has already passed, no timer is needed: the snapshot is
  /// already `due` and stays that way until [markCompleted]. While the app is
  /// backgrounded the timer may fire freely — it only re-derives state and never
  /// opens a camera; the blocking UI appears when the user returns.
  void _arm() {
    _stopTimer();
    if (!_configurationEnabled || _intervalMinutes == null) return;
    final nextDue = _schedule.nextPhotoDueAt;
    if (nextDue == null) return;
    final delay = nextDue.difference(_now());
    if (delay <= Duration.zero) return;
    _timer = Timer(delay, _onDeadline);
  }

  void _onDeadline() {
    _timer = null;
    _emit();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit() {
    final next = _build();
    if (next == _snapshot) return;
    _snapshot = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  PeriodicPhotoSnapshot _build() {
    if (!_configurationEnabled || _intervalMinutes == null) {
      // Before the first successful load nothing is known yet; after that a
      // disabled configuration is an explicit `disabled`.
      final state = _configurationLoaded
          ? PeriodicPhotoScheduleState.disabled
          : PeriodicPhotoScheduleState.unknown;
      return PeriodicPhotoSnapshot(
        state: state,
        nextPhotoDueAt: null,
        intervalMinutes: _intervalMinutes,
      );
    }
    final due = _schedule.isDueAt(_now());
    return PeriodicPhotoSnapshot(
      state: due
          ? PeriodicPhotoScheduleState.due
          : PeriodicPhotoScheduleState.waiting,
      nextPhotoDueAt: _schedule.nextPhotoDueAt,
      intervalMinutes: _intervalMinutes,
    );
  }

  Future<void> dispose() async {
    _stopTimer();
    // Deliberately not closed: nothing waits for the done event, and closing
    // after listeners have cancelled deadlocks widget-test fake async.
  }
}
