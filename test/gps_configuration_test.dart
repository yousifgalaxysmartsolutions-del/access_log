import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';

void main() {
  Map<String, dynamic> payload({
    bool? continuous,
    num? interval,
    num? accuracy,
    bool? allowOffline,
  }) => {
    'gps': {
      'enableGpsValidation': true,
      'gpsRadiusMeters': 100,
      'continuousGpsTracking': ?continuous,
      'periodicGpsCaptureIntervalMinutes': ?interval,
      'gpsAccuracyThreshold': ?accuracy,
      'allowOfflineGpsCollection': ?allowOffline,
    },
  };

  test('parses the continuous tracking fields from the payload', () {
    final config = SystemGpsConfiguration.fromJson(
      payload(continuous: true, interval: 1, accuracy: 1.0, allowOffline: true),
    );

    expect(config.continuousGpsTracking, isTrue);
    expect(config.periodicGpsCaptureIntervalMinutes, 1);
    expect(config.gpsAccuracyThreshold, 1.0);
    expect(config.allowOfflineGpsCollection, isTrue);
  });

  test('missing continuousGpsTracking fails closed', () {
    final config = SystemGpsConfiguration.fromJson(payload(interval: 5));

    expect(config.continuousGpsTracking, isFalse);
  });

  test('missing or invalid interval falls back to one minute', () {
    expect(
      SystemGpsConfiguration.fromJson(payload(continuous: true))
          .periodicGpsCaptureIntervalMinutes,
      1,
    );
    expect(
      SystemGpsConfiguration.fromJson(payload(continuous: true, interval: 0))
          .periodicGpsCaptureIntervalMinutes,
      1,
    );
  });

  test('missing gpsAccuracyThreshold stays null (never invented)', () {
    final config = SystemGpsConfiguration.fromJson(payload(continuous: true));

    expect(config.gpsAccuracyThreshold, isNull);
  });

  test('invalid radius still fails closed', () {
    expect(
      () => SystemGpsConfiguration.fromJson({
        'gps': {'enableGpsValidation': true, 'gpsRadiusMeters': 0},
      }),
      throwsFormatException,
    );
  });
}
