class SystemGpsConfiguration {
  const SystemGpsConfiguration({
    required this.radiusMeters,
    required this.enableGpsValidation,
  });
  final double radiusMeters;
  final bool enableGpsValidation;
  factory SystemGpsConfiguration.fromJson(Map<String, dynamic> json) {
    final gps = Map<String, dynamic>.from(json['gps'] as Map);
    final radius = (gps['gpsRadiusMeters'] as num).toDouble();
    if (!radius.isFinite || radius <= 0) {
      throw const FormatException('Invalid GPS radius');
    }
    return SystemGpsConfiguration(
      // TEMPORARY TEST OVERRIDE: 1,000,000 km, expressed in meters.
      // Restore the original line below after testing:
      // radiusMeters: radius,
      radiusMeters: 1000000000,
      enableGpsValidation: gps['enableGpsValidation'] as bool,
    );
  }
}
