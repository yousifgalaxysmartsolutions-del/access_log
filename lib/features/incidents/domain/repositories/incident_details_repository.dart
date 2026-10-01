import '../../../../core/network/result.dart';
import '../../data/models/incident_details_models.dart';

/// Reads the three panels of the incident details screen.
///
/// Separate methods rather than one aggregate call because each panel loads on
/// its own, and because `GetIncidentTimeline` is still untyped.
abstract interface class IncidentDetailsRepository {
  /// Details behind the "General" tab.
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  });

  /// Timeline entries for the incident.
  ///
  /// An incident with no history yields a successful [IncidentTimelineData]
  /// whose `events` is empty; that is not a failure.
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  });

  /// Requests attached to the incident ("Related Requests" tab).
  ///
  /// An incident with no requests is a success carrying an empty list.
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  });
}
