import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';

/// The `data` block of the real `GetIncidentTimeline` response, exactly as the
/// backend returned it.
///
/// Kept verbatim so every layer is tested against the actual contract rather
/// than a tidied-up version of it: fractional-second timestamps, `null`
/// `referenceId`, and the `oldValue`/`newValue` transition pair included.
const Map<String, dynamic> kTimelineDataJson = {
  'incidentId': 26,
  'incidentNo': 'INC-SEED-D10739-04',
  'events': [
    {
      'dateTime': '2026-09-11T23:24:31.963',
      'actionType': {'id': 1, 'name': 'Assign'},
      'eventType': 'Assign',
      'eventTitle': 'Incident Assigned',
      'eventDescription':
          'Incident assigned to engineer 1 — status changed to Need Approval',
      'oldValue': {'id': 1, 'name': 'Need Assign'},
      'newValue': {'id': 2, 'name': 'Need Approval'},
      'referenceId': null,
      'performedBy': {'id': 4098, 'name': 'gsm manager'},
    },
    {
      'dateTime': '2026-09-11T23:31:26.983',
      'actionType': {'id': 3, 'name': 'Approve'},
      'eventType': 'StatusChange',
      'eventTitle': 'Incident Status Changed',
      'eventDescription': 'Status changed from Need Approval to Pending',
      'oldValue': {'id': 2, 'name': 'Need Approval'},
      'newValue': {'id': 3, 'name': 'Pending'},
      'referenceId': null,
      'performedBy': {'id': 4099, 'name': 'engineer 1'},
    },
  ],
};

/// The same payload parsed into the DTO, for tests that need a typed value.
IncidentTimelineData kTimelineData() =>
    IncidentTimelineData.fromJson(kTimelineDataJson);

/// A successful but empty timeline. A valid success, not a failure.
const IncidentTimelineData kEmptyTimelineData = IncidentTimelineData(
  incidentId: 26,
  incidentNo: 'INC-SEED-D10739-04',
  events: [],
);

/// An event with every optional field null, which the payload does allow.
const IncidentTimelineEventDto kBareTimelineEvent = IncidentTimelineEventDto();

/// CAP success envelope wrapping [payload] under `data`.
Map<String, dynamic> timelineEnvelope(Map<String, dynamic> payload) => {
  'resultcode': 1,
  'resultmessageen': 'Suceess Get data',
  'resultmessagear': 'Suceess Get data',
  'data': payload,
};
