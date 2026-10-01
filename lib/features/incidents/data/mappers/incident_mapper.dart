import '../../../../models/models.dart';
import '../models/incident_list_models.dart';

/// Translates CAP incident payloads into the app's own `CapIncident` model.
///
/// The dashboard tile and the incident details screen both consume `CapIncident`,
/// so every backend-to-UI decision lives here instead of inside widgets.
abstract final class IncidentMapper {
  /// Converts the incidents returned by `GetIncidentList`.
  static List<CapIncident> toIncidents(
    List<IncidentListItem> items, {
    required DateTime requestedOn,
  }) => items
      .map((item) => toIncident(item, requestedOn: requestedOn))
      .toList(growable: false);

  static CapIncident toIncident(
    IncidentListItem item, {
    required DateTime requestedOn,
  }) {
    final status = mapStatus(id: item.statusId, name: item.statusName);
    return CapIncident(
      number: _valueOr(item.incidentNo, 'CAP-${item.incidentId}'),
      type: item.incidentType.isEmpty ? 'CAP Incident' : item.incidentType,
      siteName: item.locationName,
      siteCode: item.locationName,
      region: item.regionName,
      area: item.areaName,
      location: item.locationName,
      title: item.description,
      priority: mapPriority(id: item.priorityId, name: item.priorityName),
      // Needs Verification: `GetIncidentList` does not send a date, so
      // `CapIncident.dateTime` (non-nullable across the app) falls back to the
      // day the list was requested for. Making it nullable would ripple through
      // reporting, the incident list, the AI context builder and the details
      // screen, so the single fallback is documented here instead.
      dateTime: item.occurredAt ?? requestedOn,
      status: status,
      currentUser: item.assignedTeam.isEmpty ? 'Unassigned' : item.assignedTeam,
      description: item.description,
      needsApproval: status == CapIncidentStatus.needApproval,
    );
  }

  /// Maps a CAP status to the app status.
  ///
  /// Only `id: 3` has been observed on the wire (as `Pending`). The name is used
  /// as the primary key because CAP returns it for every row, while ids are
  /// matched only where they are actually confirmed. Needs Verification for the
  /// remaining ids.
  static CapIncidentStatus mapStatus({required int id, required String name}) {
    return switch (id) {
      3 => CapIncidentStatus.pending,
      final _ => _statusNames[_key(name)] ?? CapIncidentStatus.pending,
    };
  }

  /// Maps a CAP priority to the app priority.
  ///
  /// `id: 1` has been observed as `High`; the rest is matched by name. Needs
  /// Verification for the remaining ids.
  static Priority mapPriority({required int id, required String name}) {
    return switch (id) {
      1 => Priority.high,
      final _ => _priorityNames[_key(name)] ?? Priority.medium,
    };
  }

  static String _key(String name) => name.trim().toLowerCase();

  static const Map<String, CapIncidentStatus> _statusNames = {
    'need assign': CapIncidentStatus.needAssign,
    'need approval': CapIncidentStatus.needApproval,
    'pending': CapIncidentStatus.pending,
    'in process': CapIncidentStatus.inProcess,
    'on hold': CapIncidentStatus.hold,
    'hold': CapIncidentStatus.hold,
    'completed': CapIncidentStatus.completed,
    'closed': CapIncidentStatus.completed,
    'cancelled': CapIncidentStatus.cancelled,
    'canceled': CapIncidentStatus.cancelled,
  };

  static const Map<String, Priority> _priorityNames = {
    'low': Priority.low,
    'medium': Priority.medium,
    'moderate': Priority.medium,
    'high': Priority.high,
    'critical': Priority.critical,
    'urgent': Priority.critical,
  };

  static String _valueOr(String value, String fallback) =>
      value.isEmpty ? fallback : value;
}
