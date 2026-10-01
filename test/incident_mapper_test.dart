import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/features/incidents/data/mappers/incident_mapper.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/models/models.dart';

void main() {
  test('IncidentMapper maps pending by id and uses fallback date', () {
    final item = IncidentListItem(
      incidentId: 123,
      incidentNo: 'CAP-123',
      description: 'Network fault',
      locationName: 'Site A',
      areaName: 'Area 1',
      regionName: 'Region 1',
      incidentType: 'Alarm',
      assignedTeam: 'Team A',
      statusName: 'Pending',
      statusId: 3,
      priorityName: 'High',
      priorityId: 1,
      occurredAt: null,
    );
    final requestedOn = DateTime(2026, 8, 10, 9);
    final mapped = IncidentMapper.toIncident(item, requestedOn: requestedOn);

    expect(mapped.number, 'CAP-123');
    expect(mapped.status, CapIncidentStatus.pending);
    expect(mapped.priority, Priority.high);
    expect(mapped.dateTime, requestedOn);
  });

  test('IncidentMapper normalizes unknown status/priority by name', () {
    final item = IncidentListItem(
      incidentId: 7,
      incidentNo: '',
      description: 'desc',
      locationName: '',
      areaName: '',
      regionName: '',
      incidentType: '',
      assignedTeam: '',
      statusName: 'In Process',
      statusId: 99,
      priorityName: 'Critical',
      priorityId: 9,
    );
    final mapped = IncidentMapper.toIncident(
      item,
      requestedOn: DateTime(2026, 8, 10),
    );

    expect(mapped.status, CapIncidentStatus.inProcess);
    expect(mapped.priority, Priority.critical);
    expect(mapped.number, 'CAP-7');
  });
}
