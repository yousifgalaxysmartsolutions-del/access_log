import '../../../../core/network/cap/cap_request.dart';
import '../../domain/gps_location_record.dart';

/// The `data` block of `CAP/CapAuth/GpsTracking`.
///
/// Serialized exactly as the backend expects:
///
/// ```json
/// {
///   "IncidentId": 0,
///   "data": [
///     {
///       "LocationDateTime": "2025-09-09T12:38:49.512127",
///       "TaskLatitude": "30.0972208",
///       "TaskLongitude": "31.2163613",
///       "isoffline": true
///     }
///   ]
/// }
/// ```
///
/// The outer CAP envelope (userid/ipaddress/devicetoken/osversion/AppVersion/
/// devicetype/lang) is added by the shared request context, never here.
class GpsTrackingSyncRequestData implements CapPayload {
  const GpsTrackingSyncRequestData({
    required this.incidentId,
    required this.points,
  });

  final int incidentId;
  final List<GpsTrackingPointPayload> points;

  @override
  Map<String, dynamic> toJson() => {
    'IncidentId': incidentId,
    'data': points.map((point) => point.toJson()).toList(),
  };
}

/// One GPS point exactly as the backend expects it.
///
/// Deliberately a separate shape from [GpsLocationRecord]: the local-only
/// `localId` and `gpsAccuracyMeters` are never sent.
class GpsTrackingPointPayload {
  const GpsTrackingPointPayload({
    required this.locationDateTime,
    required this.taskLatitude,
    required this.taskLongitude,
    required this.isOffline,
  });

  final String locationDateTime;
  final String taskLatitude;
  final String taskLongitude;
  final bool isOffline;

  factory GpsTrackingPointPayload.fromRecord(GpsLocationRecord record) =>
      GpsTrackingPointPayload(
        locationDateTime: formatCapTimestamp(record.locationDateTime),
        taskLatitude: record.latitude.toStringAsFixed(7),
        taskLongitude: record.longitude.toStringAsFixed(7),
        // Preserved exactly as captured. Never recomputed at sync time, so a
        // point captured offline is still uploaded with `isoffline: true`.
        isOffline: record.isOffline,
      );

  Map<String, dynamic> toJson() => {
    'LocationDateTime': locationDateTime,
    'TaskLatitude': taskLatitude,
    'TaskLongitude': taskLongitude,
    'isoffline': isOffline,
  };
}
