import 'dart:math' as math;
import '../../../../core/error/failure.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/result.dart';
import '../repositories/system_gps_configuration_repository.dart';

class IncidentGeofenceUseCase {
  const IncidentGeofenceUseCase(this.repository);
  final SystemGpsConfigurationRepository repository;
  static bool validCoordinates(double? lat, double? long) =>
      lat != null &&
      long != null &&
      lat.isFinite &&
      long.isFinite &&
      lat.abs() <= 90 &&
      long.abs() <= 180;
  static double distanceMeters(
    double lat,
    double long,
    double siteLat,
    double siteLong,
  ) {
    double radians(double degrees) => degrees * math.pi / 180;
    final a =
        math.pow(math.sin(radians(siteLat - lat) / 2), 2) +
        math.cos(radians(lat)) *
            math.cos(radians(siteLat)) *
            math.pow(math.sin(radians(siteLong - long) / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }

  Future<Result<void>> call(
    String location, {
    required double? siteLatitude,
    required double? siteLongitude,
  }) async {
    final arabic = CapLocaleHolder.instance.isArabic;
    final parts = location.split(',');
    final lat = parts.length == 2 ? double.tryParse(parts[0].trim()) : null;
    final long = parts.length == 2 ? double.tryParse(parts[1].trim()) : null;
    if (!validCoordinates(siteLatitude, siteLongitude)) {
      return FailureResult(
        ValidationFailure(
          arabic
              ? 'إحداثيات موقع البلاغ غير متاحة. لا يمكن التحقق من موقعك.'
              : 'Incident site coordinates are unavailable. Your location cannot be verified.',
        ),
      );
    }
    if (!validCoordinates(lat, long)) {
      return FailureResult(
        ValidationFailure(
          arabic
              ? 'تعذّر تحديد موقعك. تحقق من خدمة الموقع والصلاحيات وحاول مجددًا.'
              : 'Unable to determine your location. Check location services and permissions, then retry.',
        ),
      );
    }
    final configuration = await repository.load();
    switch (configuration) {
      case FailureResult(:final failure):
        return FailureResult(failure);
      case Success(:final data):
        // gpsRequired on the selected action/request controls this gate.
        // No policies are inferred from the other system configuration flags.
        final distance = distanceMeters(
          lat!,
          long!,
          siteLatitude!,
          siteLongitude!,
        );
        if (distance > data.radiusMeters) {
          return FailureResult(
            ValidationFailure(
              arabic
                  ? 'يجب أن تكون داخل نطاق موقع البلاغ للمتابعة. المسافة الحالية: ${distance.ceil()} متر، النطاق المسموح: ${data.radiusMeters.round()} متر.'
                  : 'You must be at the incident site to continue. Current distance: ${distance.ceil()} m. Allowed radius: ${data.radiusMeters.round()} m.',
            ),
          );
        }
        return const Success(null);
    }
  }
}
