import '../../data/incident_lookup_store.dart';
import 'incident_available_action.dart';

class IncidentActionResolverService {
  // Keep the existing constructor contract; local mappings need no lookup state.
  const IncidentActionResolverService(IncidentLookupStore lookup);

  List<IncidentAvailableAction> resolve({required int? incidentStatusId}) {
    if (incidentStatusId == null) return const [];

    return switch (incidentStatusId) {
      // Need Assign
      1 => const [
        IncidentAvailableAction(
          type: IncidentAction.assign,
          actionTypeId: 1,
          flow: IncidentActionFlow.assign,
        ),
        IncidentAvailableAction(
          type: IncidentAction.cancel,
          actionTypeId: 2,
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Need Approval
      2 => const [
        IncidentAvailableAction(
          type: IncidentAction.approve,
          actionTypeId: 3,
          flow: IncidentActionFlow.actionType,
        ),
        IncidentAvailableAction(
          type: IncidentAction.reject,
          actionTypeId: 4,
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Pending
      3 => const [
        IncidentAvailableAction(
          type: IncidentAction.hold,
          actionTypeId: 8,
          flow: IncidentActionFlow.actionType,
        ),
        IncidentAvailableAction(
          type: IncidentAction.interventionRequest,
          actionTypeId: 1,
          flow: IncidentActionFlow.request,
        ),
      ],

      // In Process
      4 => const [
        IncidentAvailableAction(
          type: IncidentAction.hold,
          actionTypeId: 8,
          flow: IncidentActionFlow.actionType,
        ),
        IncidentAvailableAction(
          type: IncidentAction.renewalRequest,
          actionTypeId: 2,
          flow: IncidentActionFlow.request,
        ),
        IncidentAvailableAction(
          type: IncidentAction.complete,
          actionTypeId: 9,
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Completed
      5 => const [
        IncidentAvailableAction(
          type: IncidentAction.departureRequest,
          actionTypeId: 3,
          flow: IncidentActionFlow.request,
        ),
      ],

      // Cancelled / Hold / Rejected / Unknown
      _ => const [],
    };
  }
}
