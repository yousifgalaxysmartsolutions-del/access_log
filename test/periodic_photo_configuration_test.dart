import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';

/// `CAP/CapConfiguration/GetSystemConfiguration` — `photo` block parsing.
///
/// Fail-closed by contract: an older/partial payload must never start demanding
/// photos from the user, and no cadence may ever be invented when the backend
/// omits the interval.
void main() {
  Map<String, dynamic> payload({Object? photo}) => {
    'gps': {'enableGpsValidation': true, 'gpsRadiusMeters': 100},
    'photo': ?photo,
  };

  test('photo section absent → no periodic photo requirement', () {
    final config = SystemGpsConfiguration.fromJson(payload());

    expect(config.enablePhotoCapture, isFalse);
    expect(config.periodicPhotoCaptureIntervalMinutes, isNull);
    expect(config.requiresPeriodicPhoto, isFalse);
  });

  test('enablePhotoCapture = false → requirement off even with an interval',
      () {
    final config = SystemGpsConfiguration.fromJson(
      payload(photo: {
        'enablePhotoCapture': false,
        'periodicPhotoCaptureIntervalMinutes': 1,
      }),
    );

    expect(config.enablePhotoCapture, isFalse);
    expect(config.requiresPeriodicPhoto, isFalse);
  });

  test('enablePhotoCapture = true → interval comes from configuration', () {
    final oneMinute = SystemGpsConfiguration.fromJson(
      payload(photo: {
        'enablePhotoCapture': true,
        'periodicPhotoCaptureIntervalMinutes': 1,
      }),
    );
    final fiveMinutes = SystemGpsConfiguration.fromJson(
      payload(photo: {
        'enablePhotoCapture': true,
        'periodicPhotoCaptureIntervalMinutes': 5,
      }),
    );

    expect(oneMinute.requiresPeriodicPhoto, isTrue);
    expect(oneMinute.periodicPhotoCaptureIntervalMinutes, 1);
    expect(fiveMinutes.requiresPeriodicPhoto, isTrue);
    expect(fiveMinutes.periodicPhotoCaptureIntervalMinutes, 5);
  });

  test('missing or unusable interval → no cadence is invented', () {
    for (final interval in <Object?>[0, -3, '1', null]) {
      final config = SystemGpsConfiguration.fromJson(
        payload(photo: {
          'enablePhotoCapture': true,
          'periodicPhotoCaptureIntervalMinutes': ?interval,
        }),
      );

      expect(
        config.periodicPhotoCaptureIntervalMinutes,
        isNull,
        reason: 'interval $interval must not produce a cadence',
      );
      expect(config.requiresPeriodicPhoto, isFalse);
    }
  });

  test('fractional interval truncates like the GPS interval does', () {
    final config = SystemGpsConfiguration.fromJson(
      payload(photo: {
        'enablePhotoCapture': true,
        'periodicPhotoCaptureIntervalMinutes': 2.5,
      }),
    );

    expect(config.periodicPhotoCaptureIntervalMinutes, 2);
    expect(config.requiresPeriodicPhoto, isTrue);
  });

  test('the other mandatoryPhoto flags are ignored in this sprint', () {
    final config = SystemGpsConfiguration.fromJson(
      payload(photo: {
        'mandatoryPhotoAtTaskStart': true,
        'mandatoryPhotoDuringTask': true,
        'mandatoryPhotoBeforeDeparture': true,
        'mandatoryPhotoAtTaskCompletion': true,
        'periodicPhotoCaptureIntervalMinutes': 1,
      }),
    );

    expect(config.enablePhotoCapture, isFalse);
    expect(config.requiresPeriodicPhoto, isFalse);
  });
}
