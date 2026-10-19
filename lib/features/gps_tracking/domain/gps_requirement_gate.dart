import 'dart:async';

import 'background_location_service.dart';
import 'gps_tracking_manager.dart';

/// One centralized state for "does the CAP app satisfy the GPS requirements?".
///
/// Only [ready] and [disabledByConfiguration] allow normal app usage; every
/// other state blocks it. The state is derived, never stored as truth: it is
/// recomputed from the tracking manager and the native permission/location
/// state whenever anything changes.
enum GpsGateState {
  /// Configuration has not been loaded (or is still being loaded).
  checking,

  /// `continuousGpsTracking == false`: no GPS requirement applies.
  disabledByConfiguration,

  /// Foreground location permission is missing (not determined / denied /
  /// restricted).
  permissionRequired,

  /// Foreground location is granted but background ("Always") is not.
  backgroundPermissionRequired,

  /// Device Location Services are switched off system-wide.
  locationServicesDisabled,

  /// All conditions are met; the native tracker is being (re)started.
  startingTracker,

  /// Everything required is valid. Normal CAP usage is allowed.
  ready,

  /// Configuration could not be loaded, or the native side failed.
  error;

  /// Whether normal CAP usage is allowed in this state.
  bool get allowsUsage =>
      this == GpsGateState.ready ||
      this == GpsGateState.disabledByConfiguration;
}

/// Centralized GPS requirement coordinator.
///
/// ```text
/// SystemGpsConfigurationRepository
///         ↓
/// GpsTrackingManager
///         ↓
/// GpsRequirementGate   ← reads permission + location-services + tracker state
///         ↓
/// BackgroundLocationService → Android / iOS native
/// ```
///
/// The gate is a plain singleton service (registered in DI), not owned by a
/// screen or Bloc, so the requirement is enforced app-wide and survives
/// navigation. UI only *reads* [state]/[changes].
///
/// Reconcile entry points: cold start, authenticated session, app resume, a
/// native permission change, a Location Services change and an unexpected
/// tracker stop. Every call is idempotent and single-flight.
class GpsRequirementGate {
  GpsRequirementGate(this._manager) {
    _subscription = _manager.changes.listen((_) => _scheduleDerive());
  }

  final GpsTrackingManager _manager;

  final _changes = StreamController<GpsGateState>.broadcast();
  late final StreamSubscription<GpsTrackingStatus> _subscription;

  GpsGateState _state = GpsGateState.checking;
  GpsGateState get state => _state;

  /// State changes, for the blocking UI to render.
  Stream<GpsGateState> get changes => _changes.stream;

  Future<void>? _reconciling;
  bool _pending = false;
  bool _deriving = false;
  bool _deriveQueued = false;

  /// Full reconcile: reloads the system configuration, applies the tracking
  /// policy and re-derives the gate.
  ///
  /// Concurrent calls share one run; a call that arrives mid-run requests one
  /// follow-up pass so a trigger is never silently dropped.
  Future<void> reconcile() {
    final active = _reconciling;
    if (active != null) {
      _pending = true;
      return active;
    }
    final started = _run();
    _reconciling = started;
    return started.whenComplete(() {
      if (identical(_reconciling, started)) _reconciling = null;
      if (_pending) {
        _pending = false;
        unawaited(reconcile());
      }
    });
  }

  Future<void> _run() async {
    _set(GpsGateState.checking);
    await _manager.reconcile();
    await _derive();
  }

  /// Requests the platform permission flow, then re-derives (the native
  /// `permissionChanged` event will also trigger a derive).
  Future<LocationPermissionStatus> requestPermissions() async {
    final permission = await _manager.requestPermissions();
    await _derive();
    return permission;
  }

  /// Opens the OS location settings so the user can enable Location Services.
  Future<void> openLocationSettings() => _manager.openLocationSettings();

  void _scheduleDerive() {
    if (_deriving) {
      _deriveQueued = true;
      return;
    }
    unawaited(_derive());
  }

  /// Recomputes the gate from current manager/native state without re-fetching
  /// configuration.
  Future<void> _derive() async {
    _deriving = true;
    try {
      do {
        _deriveQueued = false;
        await _deriveOnce();
      } while (_deriveQueued);
    } finally {
      _deriving = false;
    }
  }

  Future<void> _deriveOnce() async {
    if (!_manager.hasConfiguration) {
      _set(
        _manager.status == GpsTrackingStatus.error
            ? GpsGateState.error
            : GpsGateState.checking,
      );
      return;
    }
    if (!_manager.configurationWantsTracking) {
      _set(GpsGateState.disabledByConfiguration);
      return;
    }

    final permission = await _manager.permissionStatus();
    switch (permission) {
      case LocationPermissionStatus.serviceDisabled:
        _set(GpsGateState.locationServicesDisabled);
        return;
      case LocationPermissionStatus.whenInUse:
        _set(GpsGateState.backgroundPermissionRequired);
        return;
      case LocationPermissionStatus.notDetermined:
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.restricted:
      case LocationPermissionStatus.unknown:
        _set(GpsGateState.permissionRequired);
        return;
      case LocationPermissionStatus.always:
        break;
    }

    // Permission and Location Services are satisfied: the tracker must be
    // actually running before the app is considered ready.
    if (await _manager.isNativeTracking()) {
      _set(GpsGateState.ready);
      return;
    }

    _set(GpsGateState.startingTracker);
    // Idempotent: never creates a second tracker.
    await _manager.ensureTracking();
    _set(
      await _manager.isNativeTracking()
          ? GpsGateState.ready
          : GpsGateState.startingTracker,
    );
  }

  void _set(GpsGateState value) {
    if (_state == value) return;
    _state = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    // The broadcast state stream is intentionally left unclosed: nothing ever
    // waits for its done event, and closing after listeners have cancelled
    // deadlocks the fake-async zone used by widget tests (the done future only
    // completes through a real event-loop turn there). An abandoned broadcast
    // controller with no listeners is collectable.
  }
}
