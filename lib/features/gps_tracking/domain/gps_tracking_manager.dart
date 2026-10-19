import 'dart:async';

import '../../../core/network/result.dart';
import '../../incidents/domain/repositories/system_gps_configuration_repository.dart';
import 'background_location_service.dart';

/// High-level tracking state exposed to the UI. The manager owns the decision
/// logic; the UI only renders this and forwards user intents.
enum GpsTrackingStatus {
  /// Not reconciled yet.
  unknown,

  /// Configuration disables tracking.
  disabledByConfiguration,

  /// Configured on, but required (background) permission is missing.
  awaitingPermission,

  /// Native tracker is running.
  running,

  /// Native tracker is stopped.
  stopped,

  /// Configuration could not be loaded, or the native side failed.
  error,
}

/// Orchestrates the continuous tracking policy.
///
/// ```text
/// SystemGpsConfiguration → GpsTrackingManager → BackgroundLocationService
///                                                      → Native → LocalGpsStore
/// ```
///
/// The manager is intentionally a plain singleton service, registered in DI.
/// It is not owned by a screen or Bloc, so tracking survives navigation and UI
/// teardown. The native tracker keeps running even when Flutter is suspended.
class GpsTrackingManager {
  GpsTrackingManager(this._service, this._configuration);

  final BackgroundLocationService _service;
  final SystemGpsConfigurationRepository _configuration;

  final _changes = StreamController<GpsTrackingStatus>.broadcast();
  final _events = <StreamSubscription<GpsTrackingEvent>>[];

  GpsTrackingStatus _status = GpsTrackingStatus.unknown;
  GpsTrackingStatus get status => _status;

  Stream<GpsTrackingStatus> get changes => _changes.stream;

  Future<void>? _reconciling;
  bool _listening = false;

  /// Reflects the last applied configuration so the UI can show intent even
  /// after a native restart.
  GpsTrackingConfiguration? _configurationCache;

  /// Whether the current configuration wants tracking on.
  bool get configurationWantsTracking =>
      _configurationCache?.continuousGpsTracking ?? false;

  /// Whether a system configuration has been loaded at least once.
  ///
  /// Distinguishes "we know tracking is off" from "we do not know yet", which
  /// the requirement gate needs to avoid treating an unknown config as
  /// "disabled".
  bool get hasConfiguration => _configurationCache != null;

  /// Loads the system configuration and reconciles native tracking with it.
  ///
  /// * `continuousGpsTracking == true` and permission available → start/keep.
  /// * `continuousGpsTracking == false` → stop.
  /// * configuration unavailable → leave the native tracker untouched.
  ///
  /// Concurrent calls share one run. Idempotent by design.
  Future<void> reconcile() {
    final running = _reconciling ??= _reconcile();
    return running.whenComplete(() {
      if (identical(_reconciling, running)) _reconciling = null;
    });
  }

  Future<void> _reconcile() async {
    _listen();
    final result = await _configuration.load();
    switch (result) {
      case FailureResult():
        // Do not tear down a running tracker because a refresh failed.
        _emit(GpsTrackingStatus.error);
      case Success(:final data):
        final configuration = GpsTrackingConfiguration(
          continuousGpsTracking: data.continuousGpsTracking,
          periodicGpsCaptureIntervalMinutes:
              data.periodicGpsCaptureIntervalMinutes,
          gpsAccuracyThreshold: data.gpsAccuracyThreshold,
          allowOfflineGpsCollection: data.allowOfflineGpsCollection,
        );
        _configurationCache = configuration;
        await _applyPolicy(configuration);
    }
  }

  /// Re-applies the last known configuration without re-fetching it.
  ///
  /// Used for native state-change reconciles (a permission was granted, location
  /// services were turned back on, the tracker stopped unexpectedly). The
  /// configuration API is only hit at sensible lifecycle points, never on every
  /// native event.
  Future<void> ensureTracking() async {
    _listen();
    final configuration = _configurationCache;
    if (configuration == null) return;
    await _applyPolicy(configuration);
  }

  Future<void> _applyPolicy(GpsTrackingConfiguration configuration) async {
    await _service.applyConfiguration(configuration);
    if (!configuration.continuousGpsTracking) {
      await _stopInternal();
      return;
    }
    final permission = await _service.getPermissionStatus();
    if (permission == LocationPermissionStatus.serviceDisabled) {
      _emit(GpsTrackingStatus.error);
      return;
    }
    if (!permission.grantsBackgroundTracking) {
      _emit(GpsTrackingStatus.awaitingPermission);
      return;
    }
    await _startInternal();
  }

  /// User-initiated enable: requests permissions, then reconciles.
  ///
  /// Returns the resulting status. Never loops permission prompts.
  Future<GpsTrackingStatus> enableTracking() async {
    _listen();
    final permission = await _service.requestPermissions();
    _emitPermission(permission);
    if (!permission.grantsBackgroundTracking) {
      return _status;
    }
    await reconcile();
    return _status;
  }

  /// User-initiated permission request only (no start/stop).
  Future<LocationPermissionStatus> requestPermissions() async {
    _listen();
    final permission = await _service.requestPermissions();
    _emitPermission(permission);
    return permission;
  }

  /// Stops native tracking regardless of configuration. Idempotent.
  Future<void> stopTracking() async {
    _listen();
    await _stopInternal();
  }

  Future<LocationPermissionStatus> permissionStatus() =>
      _service.getPermissionStatus();

  Future<bool> isNativeTracking() => _service.isTracking();

  /// Opens the OS location settings so the user can turn Location Services on.
  Future<void> openLocationSettings() => _service.openLocationSettings();

  Future<bool> _startInternal() async {
    if (await _service.isTracking()) {
      _emit(GpsTrackingStatus.running);
      return true;
    }
    await _service.startTracking();
    _emit(GpsTrackingStatus.running);
    return true;
  }

  Future<void> _stopInternal() async {
    if (await _service.isTracking()) {
      await _service.stopTracking();
    }
    _emit(GpsTrackingStatus.stopped);
  }

  void _emitPermission(LocationPermissionStatus permission) {
    if (permission == LocationPermissionStatus.serviceDisabled) {
      _emit(GpsTrackingStatus.error);
    } else if (!permission.grantsBackgroundTracking) {
      _emit(GpsTrackingStatus.awaitingPermission);
    }
  }

  /// Subscribes to native events once. They only refine the displayed status;
  /// capture works with or without a live Flutter listener.
  void _listen() {
    if (_listening) return;
    _listening = true;
    _events.add(
      _service.events.listen((event) {
        switch (event.type) {
          case GpsTrackingEventType.trackingStarted:
            _emit(GpsTrackingStatus.running);
          case GpsTrackingEventType.trackingStopped:
            _emit(GpsTrackingStatus.stopped);
          case GpsTrackingEventType.permissionChanged:
            final permission = event.permission;
            if (permission == null) return;
            _emitPermission(permission);
            // The OS may grant background access after the initial request
            // (e.g. the iOS "Always" upgrade) or location services may come
            // back on. Start as soon as it is available and configuration wants
            // tracking, without another user action and without re-fetching the
            // configuration.
            if (permission.grantsBackgroundTracking &&
                configurationWantsTracking) {
              unawaited(ensureTracking());
            }
          case GpsTrackingEventType.locationServicesDisabled:
          case GpsTrackingEventType.trackingError:
            _emit(GpsTrackingStatus.error);
          case GpsTrackingEventType.locationCaptured:
            // Persistence notification only; sync is triggered elsewhere so the
            // tracking engine stays independent of the upload path.
            break;
          case GpsTrackingEventType.unknown:
            break;
        }
      }, onError: (Object _) {}, onDone: () {}),
    );
  }

  void _emit(GpsTrackingStatus value) {
    _status = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() async {
    for (final subscription in _events) {
      await subscription.cancel();
    }
    _events.clear();
    await _changes.close();
  }
}
