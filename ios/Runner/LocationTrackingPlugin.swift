import CoreLocation
import Flutter
import Foundation
import Network
import UIKit

/// Channel, method and payload keys shared with Flutter.
///
/// Mirrors `lib/features/gps_tracking/gps_tracking_channels.dart` so nothing
/// drifts between the two sides.
enum GpsTrackingConstants {
  static let methodChannel = "cap/background_location"
  static let eventChannel = "cap/background_location_events"

  static let startTracking = "startTracking"
  static let stopTracking = "stopTracking"
  static let isTracking = "isTracking"
  static let applyConfiguration = "applyConfiguration"
  static let getPermissionStatus = "getPermissionStatus"
  static let requestPermissions = "requestPermissions"
  static let openLocationSettings = "openLocationSettings"

  static let argContinuous = "continuousGpsTracking"
  static let argIntervalMinutes = "periodicGpsCaptureIntervalMinutes"
  static let argAccuracyThreshold = "gpsAccuracyThreshold"
  static let argAllowOffline = "allowOfflineGpsCollection"

  static let eventKey = "event"
  static let eventPermission = "permission"
  static let eventMessage = "message"

  static let eventTrackingStarted = "trackingStarted"
  static let eventTrackingStopped = "trackingStopped"
  static let eventPermissionChanged = "permissionChanged"
  static let eventServicesDisabled = "locationServicesDisabled"
  static let eventLocationCaptured = "locationCaptured"
  static let eventError = "trackingError"

  static let permissionNotDetermined = "notDetermined"
  static let permissionWhenInUse = "whenInUse"
  static let permissionAlways = "always"
  static let permissionDenied = "denied"
  static let permissionRestricted = "restricted"
  static let permissionServiceDisabled = "serviceDisabled"
  static let permissionUnknown = "unknown"
}

/// Bridges native tracking events to Flutter *when an engine is alive*.
///
/// Capture and persistence never depend on Flutter listening.
enum GpsEventBus {
  static var sink: (([String: Any]) -> Void)?

  static func emit(
    _ event: String,
    permission: String? = nil,
    message: String? = nil
  ) {
    var payload: [String: Any] = [GpsTrackingConstants.eventKey: event]
    if let permission {
      payload[GpsTrackingConstants.eventPermission] = permission
    }
    if let message {
      payload[GpsTrackingConstants.eventMessage] = message
    }
    sink?(payload)
  }
}

/// Formats values for the CAP `GpsTracking` payload shape.
enum GpsFormatter {
  /// Fixed 7-decimal representation matching the CAP sample payload.
  static func coordinate(_ value: Double) -> String {
    String(format: "%.7f", value)
  }

  /// `yyyy-MM-ddTHH:mm:ss.SSSSSS` in local time, matching the CAP sample.
  static func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let seconds = formatter.string(from: date)
    let rawMicros = Int((date.timeIntervalSince1970 * 1_000_000).rounded(.towardZero))
    let micros = ((rawMicros % 1_000_000) + 1_000_000) % 1_000_000
    return String(format: "%@.%06d", seconds, micros)
  }
}

/// Validates native location results before they are persisted.
///
/// `gpsAccuracyThreshold` is carried in configuration but intentionally not
/// applied as a hard filter: its unit/business meaning is not established and
/// the observed sample value (1.0) would reject nearly every fix. Only clearly
/// invalid results (negative accuracy, bad coordinates) are rejected.
enum GpsPointValidator {
  static func isValidCoordinate(_ latitude: Double, _ longitude: Double) -> Bool {
    latitude.isFinite && longitude.isFinite &&
      (-90.0...90.0).contains(latitude) &&
      (-180.0...180.0).contains(longitude)
  }

  static func isUsable(_ location: CLLocation?) -> Bool {
    guard let location else { return false }
    guard isValidCoordinate(location.coordinate.latitude, location.coordinate.longitude)
    else { return false }
    if location.horizontalAccuracy < 0 { return false }
    if !location.timestamp.timeIntervalSince1970.isFinite { return false }
    return true
  }
}

/// Builds the JSON record persisted for a fix.
enum GpsRecord {
  static func make(location: CLLocation, isOffline: Bool) -> [String: Any] {
    var record: [String: Any] = [
      "localId": UUID().uuidString,
      "IncidentId": 0,
      "LocationDateTime": GpsFormatter.timestamp(location.timestamp),
      "TaskLatitude": GpsFormatter.coordinate(location.coordinate.latitude),
      "TaskLongitude": GpsFormatter.coordinate(location.coordinate.longitude),
      "isoffline": isOffline,
    ]
    if location.horizontalAccuracy >= 0 {
      record["gpsAccuracyMeters"] = location.horizontalAccuracy
    }
    return record
  }
}

/// Durable, app-private storage for captured GPS points.
///
/// Format: JSON Lines, appended with `O_APPEND` + `fsync`. A single interrupted
/// write can at worst truncate the last line, never earlier history.
///
/// Path contract shared with Dart:
/// `<applicationSupportDirectory>/cap_gps/locations.jsonl`, which is exactly
/// what Dart's `getApplicationSupportDirectory()` resolves to on iOS.
final class LocalGpsStore {
  static let directoryName = "cap_gps"
  static let fileName = "locations.jsonl"

  private let queue = DispatchQueue(label: "cap.gps.store")
  private let fileURL: URL

  init() {
    let fileManager = FileManager.default
    let base =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let directory = base.appendingPathComponent(
      LocalGpsStore.directoryName,
      isDirectory: true
    )
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent(LocalGpsStore.fileName)
  }

  func append(_ record: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: record, options: [])
    else { return }
    var payload = data
    payload.append(0x0A)
    queue.async { [fileURL] in
      LocalGpsStore.appendAtomically(url: fileURL, payload: payload)
    }
  }

  private static func appendAtomically(url: URL, payload: Data) {
    let descriptor = open(url.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    guard descriptor >= 0 else { return }
    payload.withUnsafeBytes { buffer in
      if let base = buffer.baseAddress {
        _ = write(descriptor, base, buffer.count)
      }
    }
    fsync(descriptor)
    close(descriptor)
  }
}

/// Owns the native continuous tracking engine.
///
/// Uses `CLLocationManager` and persists each accepted fix directly, so capture
/// continues while Flutter is suspended or not running. The manager is a
/// singleton so multiple `startTracking` calls never create a second engine.
final class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundLocationManager()

  private static let keyInterval = "cap_gps_interval_minutes"
  private static let keyAccuracy = "cap_gps_accuracy_threshold"
  private static let keyAllowOffline = "cap_gps_allow_offline"

  private let manager = CLLocationManager()
  private let store = LocalGpsStore()
  private let pathMonitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "cap.gps.network")
  private let stateLock = NSLock()

  private var _isOnline = true
  private var _isTracking = false
  private var interval: TimeInterval = 60
  private var accuracyThreshold: Double?
  private var allowOffline = false
  private var lastPersisted: Date?
  private var pendingPermission: ((String) -> Void)?
  private var didRequestAlways = false

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .otherNavigation
    manager.showsBackgroundLocationIndicator = true
    restoreConfiguration()
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      self.stateLock.lock()
      self._isOnline = path.status == .satisfied
      self.stateLock.unlock()
    }
    pathMonitor.start(queue: monitorQueue)
  }

  var isTracking: Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return _isTracking
  }

  private var isOnline: Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return _isOnline
  }

  // MARK: - Configuration

  func applyConfiguration(arguments: [String: Any]?) {
    let minutes = (arguments?[GpsTrackingConstants.argIntervalMinutes] as? NSNumber)?.intValue
      ?? 1
    interval = max(Double(minutes), 1) * 60
    accuracyThreshold =
      (arguments?[GpsTrackingConstants.argAccuracyThreshold] as? NSNumber)?.doubleValue
    allowOffline = arguments?[GpsTrackingConstants.argAllowOffline] as? Bool ?? false
    let defaults = UserDefaults.standard
    defaults.set(Int(interval / 60), forKey: Self.keyInterval)
    if let accuracyThreshold {
      defaults.set(accuracyThreshold, forKey: Self.keyAccuracy)
    } else {
      defaults.removeObject(forKey: Self.keyAccuracy)
    }
    defaults.set(allowOffline, forKey: Self.keyAllowOffline)
  }

  private func restoreConfiguration() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: Self.keyInterval) != nil {
      interval = max(Double(defaults.integer(forKey: Self.keyInterval)), 1) * 60
    }
    if defaults.object(forKey: Self.keyAccuracy) != nil {
      accuracyThreshold = defaults.double(forKey: Self.keyAccuracy)
    }
    allowOffline = defaults.bool(forKey: Self.keyAllowOffline)
  }

  // MARK: - Permissions

  private var authorizationStatus: CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return manager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  func currentStatusWire() -> String {
    if !CLLocationManager.locationServicesEnabled() {
      return GpsTrackingConstants.permissionServiceDisabled
    }
    return Self.wire(for: authorizationStatus)
  }

  private static func wire(for status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return GpsTrackingConstants.permissionNotDetermined
    case .restricted: return GpsTrackingConstants.permissionRestricted
    case .denied: return GpsTrackingConstants.permissionDenied
    case .authorizedAlways: return GpsTrackingConstants.permissionAlways
    case .authorizedWhenInUse: return GpsTrackingConstants.permissionWhenInUse
    @unknown default: return GpsTrackingConstants.permissionUnknown
    }
  }

  /// Requests foreground first, then upgrades to Always once, on user intent.
  func requestPermissions(completion: @escaping (String) -> Void) {
    didRequestAlways = false
    pendingPermission = completion
    switch authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      didRequestAlways = true
      manager.requestAlwaysAuthorization()
    default:
      completePermission(authorizationStatus)
    }
  }

  private func completePermission(_ status: CLAuthorizationStatus) {
    let callback = pendingPermission
    pendingPermission = nil
    let wire = Self.wire(for: status)
    GpsEventBus.emit(GpsTrackingConstants.eventPermissionChanged, permission: wire)
    DispatchQueue.main.async { callback?(wire) }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    handleAuthorizationChange()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    handleAuthorizationChange()
  }

  private func handleAuthorizationChange() {
    let status = authorizationStatus
    GpsEventBus.emit(
      GpsTrackingConstants.eventPermissionChanged,
      permission: Self.wire(for: status)
    )
    guard pendingPermission != nil else { return }
    switch status {
    case .notDetermined:
      return
    case .authorizedWhenInUse:
      if !didRequestAlways {
        didRequestAlways = true
        manager.requestAlwaysAuthorization()
        return
      }
      completePermission(status)
    default:
      completePermission(status)
    }
  }

  // MARK: - Tracking

  @discardableResult
  func startTracking() -> Bool {
    guard authorizationStatus == .authorizedAlways else {
      GpsEventBus.emit(
        GpsTrackingConstants.eventPermissionChanged,
        permission: currentStatusWire()
      )
      return false
    }
    manager.allowsBackgroundLocationUpdates = true
    manager.startUpdatingLocation()
    lastPersisted = nil
    stateLock.lock()
    _isTracking = true
    stateLock.unlock()
    GpsEventBus.emit(GpsTrackingConstants.eventTrackingStarted)
    return true
  }

  func stopTracking() {
    manager.stopUpdatingLocation()
    manager.allowsBackgroundLocationUpdates = false
    stateLock.lock()
    let wasTracking = _isTracking
    _isTracking = false
    stateLock.unlock()
    if wasTracking {
      GpsEventBus.emit(GpsTrackingConstants.eventTrackingStopped)
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard isTracking else { return }
    guard let location = locations.last else { return }
    guard GpsPointValidator.isUsable(location) else { return }
    // Approximate the configured cadence without a Dart timer. iOS may deliver
    // more or fewer callbacks in the background; we never over-capture.
    if let last = lastPersisted, location.timestamp.timeIntervalSince(last) < interval * 0.9 {
      return
    }
    lastPersisted = location.timestamp
    store.append(GpsRecord.make(location: location, isOffline: !isOnline))
    // Best-effort: notify Flutter that a point was persisted so it can attempt
    // an immediate upload. Capture never waits on this signal.
    GpsEventBus.emit(GpsTrackingConstants.eventLocationCaptured)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    GpsEventBus.emit(GpsTrackingConstants.eventError, message: error.localizedDescription)
  }
}

/// Flutter bridge: commands + live status only.
///
/// Starting/stopping and configuration go through here, but the actual capture
/// happens in [BackgroundLocationManager] regardless of this bridge.
final class LocationBridge: NSObject, FlutterStreamHandler {
  static let shared = LocationBridge()

  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSinkFlutter: FlutterEventSink?

  func register(messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(
      name: GpsTrackingConstants.methodChannel,
      binaryMessenger: messenger
    )
    method.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result)
    }
    methodChannel = method

    let events = FlutterEventChannel(
      name: GpsTrackingConstants.eventChannel,
      binaryMessenger: messenger
    )
    events.setStreamHandler(self)
    eventChannel = events

    // Location Services can be toggled in Settings while the app is backgrounded.
    // Re-evaluate on foreground so the gate can pick up the change without
    // polling from Dart.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func applicationDidBecomeActive() {
    GpsEventBus.emit(
      GpsTrackingConstants.eventPermissionChanged,
      permission: BackgroundLocationManager.shared.currentStatusWire()
    )
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case GpsTrackingConstants.startTracking:
      result(BackgroundLocationManager.shared.startTracking())
    case GpsTrackingConstants.stopTracking:
      BackgroundLocationManager.shared.stopTracking()
      result(true)
    case GpsTrackingConstants.isTracking:
      result(BackgroundLocationManager.shared.isTracking)
    case GpsTrackingConstants.applyConfiguration:
      BackgroundLocationManager.shared.applyConfiguration(
        arguments: call.arguments as? [String: Any]
      )
      result(nil)
    case GpsTrackingConstants.getPermissionStatus:
      result(BackgroundLocationManager.shared.currentStatusWire())
    case GpsTrackingConstants.requestPermissions:
      BackgroundLocationManager.shared.requestPermissions { status in
        result(status)
      }
    case GpsTrackingConstants.openLocationSettings:
      openLocationSettings()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func openLocationSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString),
      UIApplication.shared.canOpenURL(url)
    else { return }
    UIApplication.shared.open(url)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSinkFlutter = events
    GpsEventBus.sink = { [weak self] payload in
      DispatchQueue.main.async { self?.eventSinkFlutter?(payload) }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSinkFlutter = nil
    GpsEventBus.sink = nil
    return nil
  }
}
