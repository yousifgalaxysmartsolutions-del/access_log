/// Platform-channel contract for native continuous background location.
///
/// Kept in one place so the Dart and native sides never drift on channel or
/// method names. The native side mirrors these in `GpsTrackingConstants.kt`
/// and `GpsTrackingConstants` in Swift.
///
/// The actual background capture does not depend on these channels: Android
/// (`FusedLocationProviderClient` + foreground service) and iOS
/// (`CoreLocation`) capture and persist locations natively. The channels are
/// only the command/status bridge used while a Flutter engine is alive.
abstract final class GpsTrackingChannels {
  /// Command channel (`MethodChannel`).
  static const method = 'cap/background_location';

  /// Live status channel (`EventChannel`).
  static const events = 'cap/background_location_events';

  // Method names.
  static const startTracking = 'startTracking';
  static const stopTracking = 'stopTracking';
  static const isTracking = 'isTracking';
  static const applyConfiguration = 'applyConfiguration';
  static const getPermissionStatus = 'getPermissionStatus';
  static const requestPermissions = 'requestPermissions';

  // `applyConfiguration` argument keys.
  static const argContinuousGpsTracking = 'continuousGpsTracking';
  static const argIntervalMinutes = 'periodicGpsCaptureIntervalMinutes';
  static const argAccuracyThreshold = 'gpsAccuracyThreshold';
  static const argAllowOffline = 'allowOfflineGpsCollection';

  // Event payload keys.
  static const eventKey = 'event';
  static const eventPermission = 'permission';
  static const eventMessage = 'message';
}
