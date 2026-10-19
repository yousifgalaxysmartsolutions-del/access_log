/// System configuration returned by
/// `CAP/CapConfiguration/GetSystemConfiguration`.
///
/// Only the fields the app currently acts on are modelled. Unknown keys are
/// ignored so the backend can add configuration without breaking parsing.
///
/// The newer continuous-tracking fields are optional and default to a
/// fail-closed value, so an older/partial payload never silently enables
/// background tracking:
/// * [continuousGpsTracking] defaults to `false`.
/// * [periodicGpsCaptureIntervalMinutes] defaults to 1 minute only when the
///   field is missing or not a usable positive number.
///
/// The `photo` block follows the same fail-closed rule:
/// * [enablePhotoCapture] defaults to `false`.
/// * [periodicPhotoCaptureIntervalMinutes] stays `null` when missing or not a
///   usable positive number, so no cadence is ever invented.
/// * The other `mandatoryPhoto*` flags are intentionally not modelled yet.
class SystemGpsConfiguration {
  const SystemGpsConfiguration({
    required this.radiusMeters,
    required this.enableGpsValidation,
    this.continuousGpsTracking = false,
    this.periodicGpsCaptureIntervalMinutes = 1,
    this.gpsAccuracyThreshold,
    this.allowOfflineGpsCollection = false,
    this.captureGpsAtLogin = false,
    this.captureGpsAtTaskStart = false,
    this.captureGpsAtTaskCompletion = false,
    this.captureGpsDuringRequests = false,
    this.enablePhotoCapture = false,
    this.periodicPhotoCaptureIntervalMinutes,
  });

  final double radiusMeters;
  final bool enableGpsValidation;

  /// Master switch for continuous background tracking.
  ///
  /// Never hardcoded: it is read from the payload and fails closed when absent.
  final bool continuousGpsTracking;

  /// Desired capture cadence in minutes (`periodicGpsCaptureIntervalMinutes`).
  ///
  /// Translated into a native location-update strategy. The OS may deliver
  /// updates less frequently in the background.
  final int periodicGpsCaptureIntervalMinutes;

  /// Raw `gpsAccuracyThreshold` value.
  ///
  /// Its unit/business meaning is not established anywhere in the project, so
  /// it is carried through untouched and must not be reinterpreted here.
  final double? gpsAccuracyThreshold;

  /// Whether points should still be collected without connectivity.
  ///
  /// Points are always persisted locally regardless; this flag is carried for
  /// the sync policy of the next sprint.
  final bool allowOfflineGpsCollection;

  final bool captureGpsAtLogin;
  final bool captureGpsAtTaskStart;
  final bool captureGpsAtTaskCompletion;
  final bool captureGpsDuringRequests;

  /// `photo.enablePhotoCapture` — master switch for the photo feature.
  ///
  /// Defaults to `false` when absent, so an older/partial payload never
  /// suddenly demands a photo from the user.
  final bool enablePhotoCapture;

  /// `photo.periodicPhotoCaptureIntervalMinutes`.
  ///
  /// Deliberately nullable and *never* defaulted to a hardcoded cadence: when
  /// the backend omits it (or sends a non-positive value) it stays `null`, and
  /// no periodic photo requirement is derived from an invented interval.
  final int? periodicPhotoCaptureIntervalMinutes;

  /// Whether the periodic photo requirement is currently derivable.
  ///
  /// Requires both the switch and a usable interval; the other
  /// `mandatoryPhoto*` flags are intentionally not implemented yet.
  bool get requiresPeriodicPhoto =>
      enablePhotoCapture &&
      periodicPhotoCaptureIntervalMinutes != null &&
      periodicPhotoCaptureIntervalMinutes! >= 1;

  factory SystemGpsConfiguration.fromJson(Map<String, dynamic> json) {
    final gps = Map<String, dynamic>.from(json['gps'] as Map);
    final radius = (gps['gpsRadiusMeters'] as num).toDouble();
    if (!radius.isFinite || radius <= 0) {
      throw const FormatException('Invalid GPS radius');
    }
    final interval = (gps['periodicGpsCaptureIntervalMinutes'] as num?)?.toInt();
    // The `photo` block is optional: an older payload without it must never
    // start demanding photos from the user.
    final photoRaw = json['photo'];
    final photo = photoRaw is Map
        ? Map<String, dynamic>.from(photoRaw)
        : const <String, dynamic>{};
    final photoIntervalRaw = photo['periodicPhotoCaptureIntervalMinutes'];
    final photoInterval = photoIntervalRaw is num
        ? photoIntervalRaw.toInt()
        : null;
    return SystemGpsConfiguration(
      // TEMPORARY TEST OVERRIDE: 1,000,000 km, expressed in meters.
      // Restore the original line below after testing:
      // radiusMeters: radius,
      radiusMeters: 1000000000,
      enableGpsValidation: gps['enableGpsValidation'] as bool,
      continuousGpsTracking: gps['continuousGpsTracking'] as bool? ?? false,
      periodicGpsCaptureIntervalMinutes: (interval == null || interval < 1)
          ? 1
          : interval,
      gpsAccuracyThreshold: (gps['gpsAccuracyThreshold'] as num?)?.toDouble(),
      allowOfflineGpsCollection:
          gps['allowOfflineGpsCollection'] as bool? ?? false,
      captureGpsAtLogin: gps['captureGpsAtLogin'] as bool? ?? false,
      captureGpsAtTaskStart: gps['captureGpsAtTaskStart'] as bool? ?? false,
      captureGpsAtTaskCompletion:
          gps['captureGpsAtTaskCompletion'] as bool? ?? false,
      captureGpsDuringRequests:
          gps['captureGpsDuringRequests'] as bool? ?? false,
      enablePhotoCapture: photo['enablePhotoCapture'] == true,
      periodicPhotoCaptureIntervalMinutes:
          (photoInterval == null || photoInterval < 1) ? null : photoInterval,
    );
  }
}
