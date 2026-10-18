/// Platform-agnostic contract over the native continuous background tracking.
///
/// Android implements this with `FusedLocationProviderClient` behind a
/// foreground service; iOS with `CoreLocation`. UI/Blocs depend only on this
/// interface, never on platform types.
library;

/// Location authorization state, normalized across Android and iOS.
enum LocationPermissionStatus {
  /// No decision yet (iOS `notDetermined`).
  notDetermined,

  /// Foreground-only location is granted (`authorizedWhenInUse` / Android
  /// `ACCESS_FINE_LOCATION` without background access).
  whenInUse,

  /// Background location is granted (`authorizedAlways` / Android fine +
  /// `ACCESS_BACKGROUND_LOCATION`).
  always,

  /// Explicitly denied by the user.
  denied,

  /// Blocked by policy/parental controls.
  restricted,

  /// Device location services are switched off system-wide.
  serviceDisabled,

  /// Platform did not answer (e.g. unsupported platform).
  unknown;

  /// Whether continuous background tracking can run.
  bool get grantsBackgroundTracking => this == always;

  static LocationPermissionStatus fromWire(Object? value) => switch ('$value') {
    'notDetermined' => notDetermined,
    'whenInUse' => whenInUse,
    'always' => always,
    'denied' => denied,
    'restricted' => restricted,
    'serviceDisabled' => serviceDisabled,
    _ => unknown,
  };

  String toWire() => name;
}

/// Live status events emitted by the native tracker while Flutter is running.
enum GpsTrackingEventType {
  trackingStarted,
  trackingStopped,
  permissionChanged,
  locationServicesDisabled,
  trackingError,
  unknown;

  static GpsTrackingEventType fromWire(Object? value) =>
      switch ('$value') {
        'trackingStarted' => trackingStarted,
        'trackingStopped' => trackingStopped,
        'permissionChanged' => permissionChanged,
        'locationServicesDisabled' => locationServicesDisabled,
        'trackingError' => trackingError,
        _ => unknown,
      };
}

class GpsTrackingEvent {
  const GpsTrackingEvent({required this.type, this.permission, this.message});

  final GpsTrackingEventType type;
  final LocationPermissionStatus? permission;
  final String? message;

  static GpsTrackingEvent fromWire(Object? raw) {
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    final permission = map['permission'];
    return GpsTrackingEvent(
      type: GpsTrackingEventType.fromWire(map['event']),
      permission: permission == null
          ? null
          : LocationPermissionStatus.fromWire(permission),
      message: map['message'] as String?,
    );
  }
}

/// The subset of system configuration the native tracker needs.
///
/// Typed/simple values only, matching the `applyConfiguration` channel payload.
class GpsTrackingConfiguration {
  const GpsTrackingConfiguration({
    required this.continuousGpsTracking,
    required this.periodicGpsCaptureIntervalMinutes,
    this.gpsAccuracyThreshold,
    this.allowOfflineGpsCollection = false,
  });

  final bool continuousGpsTracking;
  final int periodicGpsCaptureIntervalMinutes;

  /// Passed through untouched; its meaning is not reinterpreted in Dart.
  final double? gpsAccuracyThreshold;
  final bool allowOfflineGpsCollection;

  Map<String, Object?> toChannelArguments() => {
    'continuousGpsTracking': continuousGpsTracking,
    'periodicGpsCaptureIntervalMinutes': periodicGpsCaptureIntervalMinutes,
    'gpsAccuracyThreshold': gpsAccuracyThreshold,
    'allowOfflineGpsCollection': allowOfflineGpsCollection,
  };
}

/// Commands and status for native continuous background tracking.
///
/// Implementations must be safe to call repeatedly: starting an already
/// running tracker is a no-op, not a second tracker.
abstract interface class BackgroundLocationService {
  /// Pushes the desired capture policy to the native side.
  ///
  /// Does not start or stop tracking by itself.
  Future<void> applyConfiguration(GpsTrackingConfiguration configuration);

  /// Starts (or keeps) native tracking. Idempotent.
  ///
  /// Must only be called when the required permission is already granted.
  Future<void> startTracking();

  /// Stops native tracking. Idempotent.
  Future<void> stopTracking();

  /// Whether native tracking is currently running.
  Future<bool> isTracking();

  /// Current normalized authorization state.
  Future<LocationPermissionStatus> getPermissionStatus();

  /// Triggers the platform permission flow and resolves with the new state.
  Future<LocationPermissionStatus> requestPermissions();

  /// Native status events. Never required for capture to work.
  Stream<GpsTrackingEvent> get events;
}
