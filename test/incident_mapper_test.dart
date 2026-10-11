import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:access_log_plus/features/incidents/data/mappers/incident_mapper.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/widgets/cap_incident_card.dart';
import 'package:access_log_plus/screens/dashboard/cap_dashboard_screen.dart';

Map<String, dynamic> incidentPayload({
  int statusId = 7,
  String status = 'Hold',
}) => {
  'incidentId': 26,
  'incidentTitle': 'Test Incident - D10739',
  'incidentNo': 'INC-SEED-D10739-04',
  'locationName': 'site b2',
  'locationCode': null,
  'locationId': 'D10739',
  'createdDate': '2026-09-30T14:15:09',
  'region': {'id': 81, 'name': 'Giza'},
  'area': {'id': 90, 'name': 'El Ayat'},
  'status': {'id': statusId, 'name': status},
  'incidentType': {'id': 1, 'name': 'X2 Interface Fault'},
  'priority': {'id': 1, 'name': 'High'},
  'currentUser': {'id': 4099, 'name': 'engineer 1'},
};

void main() {
  test('live nested fields retain API names and createdDate', () {
    final incident = IncidentMapper.toIncident(
      IncidentListItem.fromJson(incidentPayload()),
      requestedOn: DateTime(2026, 10, 11),
    );
    expect(incident.region, 'Giza');
    expect(incident.area, 'El Ayat');
    expect(incident.type, 'X2 Interface Fault');
    expect(incident.currentUser, 'engineer 1');
    expect(incident.siteName, 'site b2');
    expect(incident.siteCode, 'D10739');
    expect(incident.displayStatus, 'Hold');
    expect(incident.displayPriority, 'High');
    expect(incident.status, CapIncidentStatus.hold);
    expect(incident.hasRealDate, isTrue);
    expect(incident.dateTime, DateTime(2026, 9, 30, 14, 15, 9));
    expect(formatIncidentCreatedDate(incident.dateTime), '30/09/2026 • 14:15');
  });

  test('missing or malformed values do not become JSON or mock text', () {
    final incident = IncidentMapper.toIncident(
      IncidentListItem.fromJson({
        'region': {'id': 81},
        'area': [],
      }),
      requestedOn: DateTime(2026),
    );
    expect(incident.region, '');
    expect(incident.area, '');
    expect(incident.number, '');
    expect(incident.type, '');
    expect(incident.currentUser, '');
    expect(incident.displayStatus, '');
    expect(incident.hasRealDate, isFalse);
  });

  for (final language in ['ar', 'en']) {
    testWidgets('API labels stay unchanged in $language on small phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final incident = IncidentMapper.toIncident(
        IncidentListItem.fromJson(
          incidentPayload(statusId: 8, status: 'Rejected'),
        ),
        requestedOn: DateTime(2026),
      );
      for (final card in [
        CapIncidentCard(incident: incident),
        CompactIncidentTile(incident: incident),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(body: SingleChildScrollView(child: card)),
            ),
          ),
        );
        expect(find.text('Rejected'), findsOneWidget);
        expect(find.text('30/09/2026 • 14:15'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

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
    expect(mapped.number, '');
  });
}
