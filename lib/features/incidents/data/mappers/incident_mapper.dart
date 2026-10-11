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
      incidentId: item.incidentId,
      backendStatusId: item.statusId,
      backendStatusName: item.statusName,
      backendPriorityName: item.priorityName,
      number: item.incidentNo,
      type: item.incidentType,
      siteName: item.locationName,
      siteCode: item.locationCode,
      region: item.regionName,
      area: item.areaName,
      location: item.locationName,
      title: item.description,
      priority: mapPriority(id: item.priorityId, name: item.priorityName),
      // Keep the non-nullable internal date; never display it when absent in CAP.
      dateTime: item.occurredAt ?? requestedOn,
      hasRealDate: item.occurredAt != null,
      status: status,
      currentUser: item.assignedTeam,
      description: item.description,
      productName: '',
      nativeMoName: '',
      notificationType: '',
      needsApproval: status == CapIncidentStatus.needApproval,
    );
  }

  /// Maps a CAP status to the app status.
  ///
  /// Confirmed CAP ids. Display text is preserved separately, not reconstructed.
  static CapIncidentStatus mapStatus({required int id, required String name}) {
    return switch (id) {
      1 => CapIncidentStatus.needAssign,
      2 => CapIncidentStatus.needApproval,
      3 => CapIncidentStatus.pending,
      4 => CapIncidentStatus.inProcess,
      5 => CapIncidentStatus.completed,
      6 => CapIncidentStatus.cancelled,
      7 => CapIncidentStatus.hold,
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
}
