import 'dart:io';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

typedef CapUserCoordinates = ({double latitude, double longitude});

/// Device and application facts that CAP expects on every request.
class CapDeviceAppInfo {
  const CapDeviceAppInfo({
    required this.osVersion,
    required this.deviceType,
    required this.appVersion,
    this.deviceToken,
  });

  final String osVersion;

  /// `iOS` or `Android`, using the backend's exact casing.
  final String deviceType;

  final String appVersion;

  /// Push registration token, when one has been captured.
  final String? deviceToken;
}

/// Resolves [CapDeviceAppInfo] from the running platform.
///
/// `osversion` and `devicetype` come from `dart:io` and therefore need no extra
/// dependency. `AppVersion` comes from `package_info_plus` because Flutter
/// exposes no platform API for the installed app version.
class CapDeviceAppInfoProvider {
  /// Optional cached GPS only. Never requests permission, obtains a new fix,
  /// validates a geofence or changes the background tracking configuration.
  static Future<CapUserCoordinates?> readAvailableCoordinates() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    final position = await Geolocator.getLastKnownPosition();
    if (position == null ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      return null;
    }
    return (latitude: position.latitude, longitude: position.longitude);
  }

  CapDeviceAppInfoProvider({
    String? osVersion,
    String? deviceType,
    String? appVersion,
    this.deviceToken,
    this.appVersionLoader = _defaultAppVersionLoader,
    this.deviceIdentifierLoader,
  }) : _osVersionOverride = osVersion,
       _deviceTypeOverride = deviceType,
       _appVersionOverride = appVersion;

  static Future<String> _defaultAppVersionLoader() async {
    final info = await PackageInfo.fromPlatform();
    // Needs Verification: the only CAP payload this project has ever sent used
    // the build number ("1"), so that is what keeps being sent. Switching to
    // the semantic version ("1.0.0") would be an unverified contract change.
    return info.buildNumber.trim().isEmpty ? info.version : info.buildNumber;
  }

  final String? _osVersionOverride;
  final String? _deviceTypeOverride;
  final String? _appVersionOverride;

  /// Push token source. Null until a real push registration is wired up.
  final String? deviceToken;

  /// Overridable so tests can resolve `AppVersion` without platform channels.
  final Future<String> Function() appVersionLoader;
  final Future<String> Function()? deviceIdentifierLoader;
  Future<String>? _deviceIdentifier;

  /// Stable installation identifier for public CAP envelopes. Existing signed-in
  /// request metadata is intentionally unchanged. No hardware identifier or
  /// sample device value is fabricated when secure storage is unavailable.
  Future<String> resolveDeviceIdentifier() async {
    final loading = _deviceIdentifier ??= _loadDeviceIdentifier();
    try {
      return await loading;
    } catch (_) {
      if (identical(_deviceIdentifier, loading)) _deviceIdentifier = null;
      rethrow;
    }
  }

  Future<String> _loadDeviceIdentifier() async {
    if (deviceIdentifierLoader != null) return deviceIdentifierLoader!();
    const override = String.fromEnvironment('CAP_DEVICE_ID');
    if (override.trim().isNotEmpty) return override;
    const storage = FlutterSecureStorage();
    const key = 'cap_installation_identifier';
    final saved = await storage.read(key: key);
    if (saved != null && saved.isNotEmpty) return saved;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.write(key: key, value: id);
    return id;
  }

  CapDeviceAppInfo? _cached;

  CapDeviceAppInfo? get cached => _cached;

  Future<CapDeviceAppInfo> resolve() async {
    final info = CapDeviceAppInfo(
      osVersion: _osVersionOverride ?? _formatOsVersion(currentOsVersion()),
      deviceType: _deviceTypeOverride ?? currentDeviceType(),
      appVersion: await _resolveAppVersion(),
      deviceToken: deviceToken,
    );
    _cached = info;
    return info;
  }

  Future<String> _resolveAppVersion() async {
    final override = _appVersionOverride;
    if (override != null && override.isNotEmpty) return override;
    try {
      final loaded = await appVersionLoader();
      return loaded.isEmpty ? unknownVersion : loaded;
    } on Object {
      // `package_info_plus` has no platform implementation under `flutter_test`,
      // so an unreadable version must not take the whole screen down.
      return unknownVersion;
    }
  }

  /// Raw platform string, e.g. `Version 15.1.0 (Build 19B81)` on iOS.
  static String currentOsVersion() => Platform.operatingSystemVersion;

  static String currentDeviceType() {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    // CAP only supports mobile; desktop only shows up in tests and tooling.
    return 'iOS';
  }

  static const String unknownVersion = '0';

  /// Normalizes the raw platform string to the `major.minor` shape CAP uses.
  ///
  /// Needs Verification: only `15.1` has ever been observed on the wire, so the
  /// exact formatting rule the backend expects is still unconfirmed.
  static String _formatOsVersion(String raw) {
    final cleaned = raw.replaceFirst('Version', '').trim();
    final match = RegExp(r'(\d+)(?:\.(\d+))?').firstMatch(cleaned);
    if (match == null) return cleaned;
    final major = match.group(1)!;
    final minor = match.group(2);
    return minor == null ? '$major.0' : '$major.$minor';
  }
}
