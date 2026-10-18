// import '../../data/incident_lookup_store.dart';
// import 'incident_available_action.dart';
//
// class IncidentActionResolverService {
//   // Keep the existing constructor contract; local mappings need no lookup state.
//   const IncidentActionResolverService(IncidentLookupStore lookup);
//
//   List<IncidentAvailableAction> resolve({required int? incidentStatusId}) {
//     if (incidentStatusId == null) return const [];
//
//     return switch (incidentStatusId) {
//       // Need Assign
//       1 => const [
//         IncidentAvailableAction(
//           type: IncidentAction.assign,
//           actionTypeId: 1,
//           flow: IncidentActionFlow.assign,
//         ),
//         IncidentAvailableAction(
//           type: IncidentAction.cancel,
//           actionTypeId: 2,
//           flow: IncidentActionFlow.actionType,
//         ),
//       ],
//
//       // Need Approval
//       2 => const [
//         IncidentAvailableAction(
//           type: IncidentAction.approve,
//           actionTypeId: 3,
//           flow: IncidentActionFlow.actionType,
//         ),
//         IncidentAvailableAction(
//           type: IncidentAction.reject,
//           actionTypeId: 4,
//           flow: IncidentActionFlow.actionType,
//         ),
//       ],
//
//       // Pending
//       3 => const [
//         IncidentAvailableAction(
//           type: IncidentAction.hold,
//           actionTypeId: 8,
//           flow: IncidentActionFlow.actionType,
//         ),
//         IncidentAvailableAction(
//           type: IncidentAction.interventionRequest,
//           actionTypeId: 1,
//           flow: IncidentActionFlow.request,
//         ),
//       ],
//
//       // In Process
//       4 => const [
//         IncidentAvailableAction(
//           type: IncidentAction.hold,
//           actionTypeId: 8,
//           flow: IncidentActionFlow.actionType,
//         ),
//         IncidentAvailableAction(
//           type: IncidentAction.renewalRequest,
//           actionTypeId: 2,
//           flow: IncidentActionFlow.request,
//         ),
//         IncidentAvailableAction(
//           type: IncidentAction.complete,
//           actionTypeId: 9,
//           flow: IncidentActionFlow.actionType,
//         ),
//       ],
//
//       // Completed
//       5 => const [
//         IncidentAvailableAction(
//           type: IncidentAction.departureRequest,
//           actionTypeId: 3,
//           flow: IncidentActionFlow.request,
//         ),
//       ],
//
//       // Cancelled / Hold / Rejected / Unknown
//       _ => const [],
//     };
//   }
// }

import '../../data/incident_lookup_store.dart';
import '../../../../core/storage/secure_storage_service.dart';
import 'incident_available_action.dart';

class IncidentActionResolverService {
  // Keep the existing constructor contract; local mappings need no lookup state.
  const IncidentActionResolverService(IncidentLookupStore lookup);

  List<IncidentAvailableAction> resolve({
    required int? incidentStatusId,
    SessionUser? user,
    int? assignedEngineerId,
  }) {
    if (incidentStatusId == null) return const [];
    if (incidentStatusId == 2) {
      if (user?.isSupervisor == true) {
        return const [
          IncidentAvailableAction(
            type: IncidentAction.reassign,
            actionTypeId: 1,
            newStatusId: null,
            flow: IncidentActionFlow.assign,
          ),
          IncidentAvailableAction(
            type: IncidentAction.reject,
            actionTypeId: 4,
            newStatusId: 1,
            flow: IncidentActionFlow.actionType,
          ),
        ];
      }
      if (user?.isEngineer == true &&
          assignedEngineerId != null &&
          assignedEngineerId > 0 &&
          user!.numericId == assignedEngineerId) {
        return const [
          IncidentAvailableAction(
            type: IncidentAction.approve,
            actionTypeId: 3,
            newStatusId: 3,
            flow: IncidentActionFlow.actionType,
          ),
        ];
      }
      return const [];
    }

    return switch (incidentStatusId) {
      // Need Assign
      1 => const [
        IncidentAvailableAction(
          type: IncidentAction.assign,
          actionTypeId: 1,
          newStatusId: null,
          flow: IncidentActionFlow.assign,
        ),
        IncidentAvailableAction(
          type: IncidentAction.cancel,
          actionTypeId: 2,
          newStatusId: 6, // Cancelled
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Pending
      3 => const [
        IncidentAvailableAction(
          type: IncidentAction.hold,
          actionTypeId: 8,
          newStatusId: 7, // Hold
          flow: IncidentActionFlow.actionType,
        ),
        IncidentAvailableAction(
          type: IncidentAction.interventionRequest,
          actionTypeId: 1,
          newStatusId: null,
          flow: IncidentActionFlow.request,
        ),
      ],

      // In Process
      4 => const [
        IncidentAvailableAction(
          type: IncidentAction.hold,
          actionTypeId: 8,
          newStatusId: 7, // Hold
          flow: IncidentActionFlow.actionType,
        ),
        IncidentAvailableAction(
          type: IncidentAction.renewalRequest,
          actionTypeId: 2,
          newStatusId: null,
          flow: IncidentActionFlow.request,
        ),
        IncidentAvailableAction(
          type: IncidentAction.complete,
          actionTypeId: 9,
          newStatusId: 5, // Completed
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Completed
      5 => const [
        IncidentAvailableAction(
          type: IncidentAction.departureRequest,
          actionTypeId: 3,
          newStatusId: null,
          flow: IncidentActionFlow.request,
        ),
      ],

      // Hold: the backend restores the previous status when NewStatusId is 0.
      7 => const [
        IncidentAvailableAction(
          type: IncidentAction.unHold,
          actionTypeId: incidentUnHoldActionTypeId,
          newStatusId: 0,
          flow: IncidentActionFlow.actionType,
        ),
      ],

      // Cancelled / Rejected / Unknown
      _ => const [],
    };
  }
}
