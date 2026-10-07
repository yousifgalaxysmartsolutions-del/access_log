// enum IncidentAction {
//   assign,
//   cancel,
//   approve,
//   reject,
//   hold,
//   interventionRequest,
//   renewalRequest,
//   complete,
//   departureRequest,
// }
//
// enum IncidentActionFlow { assign, actionType, request }
//
// class IncidentAvailableAction {
//   const IncidentAvailableAction({
//     required this.type,
//     required this.actionTypeId,
//     required this.flow,
//   });
//   final IncidentAction type;
//
//   /// From Incident Lookup.actionType; never a RequestTypeId.
//   final int actionTypeId;
//   final IncidentActionFlow flow;
// }


enum IncidentAction {
  assign,
  cancel,
  approve,
  reject,
  hold,
  interventionRequest,
  renewalRequest,
  complete,
  departureRequest,
}

enum IncidentActionFlow {
  assign,
  actionType,
  request,
}

class IncidentAvailableAction {
  const IncidentAvailableAction({
    required this.type,
    required this.actionTypeId,
    required this.newStatusId,
    required this.flow,
  });

  final IncidentAction type;

  /// Keep the existing ID meaning based on the current flow.
  final int actionTypeId;

  /// Target incident status.
  ///
  /// Null when:
  /// - the status is dynamic, like Assign
  /// - the action belongs to Request flow
  final int? newStatusId;

  final IncidentActionFlow flow;
}
