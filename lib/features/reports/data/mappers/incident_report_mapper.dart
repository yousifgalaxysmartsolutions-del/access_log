import '../../../../models/models.dart';
import '../../../incidents/data/mappers/incident_mapper.dart';
import '../../../incidents/data/models/incident_list_models.dart';
import '../models/incident_report_models.dart';

abstract final class IncidentReportMapper {
  static CapIncident toIncident(
    IncidentReportItem item,
  ) => IncidentMapper.toIncident(
    IncidentListItem(
      incidentId: item.id ?? 0,
      incidentNo: item.incidentNo ?? '—',
      description: item.title ?? '—',
      locationName: item.locationName ?? '—',
      locationCode: item.locationCode ?? '',
      areaName: item.area?.name ?? '—',
      regionName: item.region?.name ?? '—',
      incidentType: '',
      assignedTeam: item.assignedToLabel ?? '—',
      statusName: item.status?.name ?? '—',
      statusId: item.status?.id ?? -1,
      priorityName: item.priority?.name ?? '—',
      priorityId: item.priority?.id ?? -1,
      occurredAt: DateTime.tryParse(item.raisedTime ?? ''),
    ),
    // The legacy model requires a date; hasRealDate hides it when CAP omits one.
    requestedOn: DateTime(1970),
  );
}
