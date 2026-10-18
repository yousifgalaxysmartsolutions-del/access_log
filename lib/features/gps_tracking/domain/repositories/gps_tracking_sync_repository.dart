import '../../../../core/network/result.dart';
import '../gps_location_record.dart';

/// Uploads one batch of locally stored GPS points to `CAP/CapAuth/GpsTracking`.
///
/// Networking only: connectivity checks, batching, single-flight locking,
/// deletion of accepted points and retry triggers live in
/// `GpsTrackingSyncService`. Implementations must never delete or mutate local
/// data.
abstract interface class GpsTrackingSyncRepository {
  /// Returns `Success(true)` only when CAP itself reports success
  /// (`resultcode == 1`). Any transport error, HTTP error, CAP failure or parse
  /// problem is a `FailureResult`, and the caller must keep the records.
  Future<Result<bool>> upload({
    required int incidentId,
    required List<GpsLocationRecord> records,
  });
}
