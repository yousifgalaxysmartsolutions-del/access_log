import '../../../forms/data/models/cap_form_models.dart';
import '../../../../core/network/result.dart';

/// Uploads one captured photo to `CAP/CapIncident/SavePeriodicPhoto`.
///
/// Networking only: timing policy, retention of a captured-but-unsubmitted
/// photo and retry scheduling live in `PeriodicPhotoCoordinator` /
/// `PeriodicPhotoGate`. Implementations never mutate local schedule state.
abstract interface class PeriodicPhotoRepository {
  /// Returns `Success(true)` only when CAP itself reports success
  /// (`resultcode == 1`). Any transport error, HTTP error, CAP failure or parse
  /// problem is a `FailureResult`, and the caller must keep the captured photo.
  ///
  /// The captured bytes are always submitted as-is; this never decides that a
  /// failed call was a success.
  Future<Result<bool>> submit({
    required int incidentId,
    required CapFormEvidence evidence,
  });
}
