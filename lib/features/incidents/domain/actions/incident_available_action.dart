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

enum IncidentActionFlow { assign, actionType, request }

class IncidentAvailableAction {
  const IncidentAvailableAction({
    required this.type,
    required this.actionTypeId,
    required this.flow,
  });
  final IncidentAction type;

  /// From Incident Lookup.actionType; never a RequestTypeId.
  final int actionTypeId;
  final IncidentActionFlow flow;
}
