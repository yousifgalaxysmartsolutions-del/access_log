import '../../data/incident_lookup_store.dart';
import 'incident_available_action.dart';

class IncidentActionResolverService {
  const IncidentActionResolverService(this._lookup);
  final IncidentLookupStore _lookup;

  List<IncidentAvailableAction> resolve({required int? incidentStatusId}) {
    final lookup = _lookup.current;
    if (lookup == null || incidentStatusId == null) return const [];
    final statuses = lookup.status
        .where((item) => item.id == incidentStatusId)
        .toList();
    if (statuses.length != 1) return const [];
    final types = switch (_key(statuses.single.code)) {
      'need_assign' => [IncidentAction.assign, IncidentAction.cancel],
      'need_approval' => [IncidentAction.approve, IncidentAction.reject],
      'pending' => [IncidentAction.hold, IncidentAction.interventionRequest],
      'in_process' => [
        IncidentAction.hold,
        IncidentAction.renewalRequest,
        IncidentAction.complete,
      ],
      'completed' => [IncidentAction.departureRequest],
      _ => <IncidentAction>[],
    };
    final actions = <IncidentAvailableAction>[];
    for (final type in types) {
      final (code, flow) = switch (type) {
        IncidentAction.assign => ('assign', IncidentActionFlow.assign),
        IncidentAction.cancel => ('cancel', IncidentActionFlow.actionType),
        IncidentAction.approve => ('approve', IncidentActionFlow.actionType),
        IncidentAction.reject => ('reject', IncidentActionFlow.actionType),
        IncidentAction.hold => ('hold', IncidentActionFlow.actionType),
        IncidentAction.complete => ('complete', IncidentActionFlow.actionType),
        IncidentAction.interventionRequest => (
          'intervention',
          IncidentActionFlow.request,
        ),
        IncidentAction.renewalRequest => (
          'renewal',
          IncidentActionFlow.request,
        ),
        IncidentAction.departureRequest => (
          'departure',
          IncidentActionFlow.request,
        ),
      };
      final matches = lookup.actionType
          .where((item) => _key(item.code) == code)
          .toList();
      // Missing, invalid or ambiguous metadata must not create executable IDs.
      if (matches.length != 1) continue;
      final id = matches.single.id;
      if (id == null || id <= 0) continue;
      actions.add(
        IncidentAvailableAction(type: type, actionTypeId: id, flow: flow),
      );
    }
    return List.unmodifiable(actions);
  }

  static String _key(String? value) => value?.trim().toLowerCase() ?? '';
}
