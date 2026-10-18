import 'gps_location_record.dart';

/// Read/delete side of the local GPS store, used by the sync service.
///
/// The concrete `LocalGpsStore` (data layer) implements this port, so the sync
/// policy depends on an abstraction instead of the file format. This keeps the
/// "local storage" and "server sync" responsibilities separable and testable.
abstract interface class GpsPendingStore {
  /// Every valid stored point, oldest first. Malformed lines are skipped.
  Future<List<GpsLocationRecord>> readAll();

  /// Removes exactly the points whose [GpsLocationRecord.localId] is in
  /// [localIds] and returns how many were removed.
  ///
  /// Implementations must be atomic and must never drop points that were
  /// appended after the sync batch was read.
  Future<int> removeByIds(Set<String> localIds);

  /// Number of stored points.
  Future<int> count();
}
