import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

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
  CapDeviceAppInfoProvider({
    String? osVersion,
    String? deviceType,
    String? appVersion,
    this.deviceToken,
    this.appVersionLoader = _defaultAppVersionLoader,
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
