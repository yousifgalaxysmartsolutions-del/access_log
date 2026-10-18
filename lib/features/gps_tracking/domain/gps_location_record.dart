/// A single locally persisted GPS point.
///
/// The JSON shape matches the CAP `GpsTracking` payload the next sprint will
/// send, plus a local-only [localId] and [accuracyMeters]. Extra local fields
/// are ignored by the sync mapper; the backend contract only needs the five
/// documented keys.
///
/// Native Android/iOS write this same shape directly to the shared local file,
/// so both producers and the Dart reader must stay in sync.
class GpsLocationRecord {
  const GpsLocationRecord({
    required this.localId,
    required this.locationDateTime,
    required this.latitude,
    required this.longitude,
    required this.isOffline,
    this.incidentId = 0,
    this.accuracyMeters,
  });

  /// Local-only identifier. Never sent to the backend; used to delete a record
  /// only after it has been accepted by the server in the next sprint.
  final String localId;

  /// CAP `IncidentId`. Continuous user tracking uses `0`; no incident
  /// assignment logic is invented here.
  final int incidentId;

  /// Wall-clock time the fix was captured, in the device's local time.
  ///
  /// Serialized as `yyyy-MM-ddTHH:mm:ss.SSSSSS` (no timezone suffix) to match
  /// the backend sample. `Needs Verification`: the zone convention of the
  /// backend contract has not been confirmed.
  final DateTime locationDateTime;

  final double latitude;
  final double longitude;

  /// Whether the device had no usable network at capture time.
  final bool isOffline;

  /// Horizontal accuracy in meters when the platform reported one. Local-only.
  final double? accuracyMeters;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'IncidentId': incidentId,
    'LocationDateTime': formatCapTimestamp(locationDateTime),
    'TaskLatitude': latitude.toStringAsFixed(7),
    'TaskLongitude': longitude.toStringAsFixed(7),
    'isoffline': isOffline,
    if (accuracyMeters != null) 'gpsAccuracyMeters': accuracyMeters,
  };

  factory GpsLocationRecord.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['TaskLatitude']}');
    final long = double.tryParse('${json['TaskLongitude']}');
    final when = DateTime.tryParse('${json['LocationDateTime']}');
    if (lat == null || long == null || when == null) {
      throw const FormatException('Invalid GPS record');
    }
    return GpsLocationRecord(
      localId: '${json['localId'] ?? ''}',
      incidentId: (json['IncidentId'] as num?)?.toInt() ?? 0,
      locationDateTime: when,
      latitude: lat,
      longitude: long,
      isOffline: json['isoffline'] == true,
      accuracyMeters: (json['gpsAccuracyMeters'] as num?)?.toDouble(),
    );
  }
}

/// Formats an ISO-8601 wall-clock timestamp with microsecond precision and no
/// timezone suffix, matching the CAP sample `2025-09-09T12:38:49.512127`.
String formatCapTimestamp(DateTime value) {
  final local = value.toLocal();
  String pad(int number, int width) => number.toString().padLeft(width, '0');
  final microseconds = local.millisecond * 1000 + local.microsecond;
  return '${pad(local.year, 4)}-${pad(local.month, 2)}-${pad(local.day, 2)}'
      'T${pad(local.hour, 2)}:${pad(local.minute, 2)}:${pad(local.second, 2)}'
      '.${pad(microseconds, 6)}';
}
