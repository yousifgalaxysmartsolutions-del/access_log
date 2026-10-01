import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/network/cap/cap_request.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';

import 'support/timeline_fixtures.dart';

/// Verbatim `data` payload of `CAP/CapIncident/GetIncidentDetails`.
const Map<String, dynamic> kIncidentDetailsData = {
  'id': 26,
  'incidentNo': 'INC-SEED-D10739-04',
  'title': 'Test Incident - D10739',
  'description': 'Seeded sample incident (Need Assign) for location D10739',
  'alarmId': null,
  'alarmName': 'test',
  'productName': null,
  'nativeMoName': null,
  'raisedTime': '2026-09-30T14:22:14',
  'clearedTime': null,
  'createdDate': '2026-09-30T14:22:14',
  'startDate': '2026-09-30T14:22:14',
  'closedDate': null,
  'lastModifiedDate': '2026-09-11T23:31:26.983',
  'alarmType': {'id': 1, 'name': 'X2 Interface Fault'},
  'incidentType': {'id': 1, 'name': 'X2 Interface Fault'},
  'priority': {'id': 1, 'name': 'High'},
  'status': {'id': 3, 'name': 'Pending'},
  'notificationType': {'id': 1, 'name': 'manual'},
  'assignedEngineer': {'id': 4099, 'name': 'engineer 1'},
  'lastModifiedBy': {'id': 4099, 'name': 'engineer 1'},
  'location': {
    'id': 'D10739',
    'name': 'site b2',
    'region': {'id': 81, 'name': 'Giza'},
    'area': {'id': 90, 'name': 'El Ayat'},
    'latitude': 31.345689615304693,
    'longitude': 30.056498596656265,
  },
};

/// The `data` block of the LIVE `GetIncidentDetails` response.
///
/// Kept verbatim, including `"alarmId": "1"` as a JSON **string**. That single
/// detail is the whole point of this fixture: it is what the generated
/// `(json['alarmId'] as num?)` cast rejected with
/// `type 'String' is not a subtype of type 'num?'`.
///
/// The eight fields the contract review called out - `nativeMoName`,
/// `clearedTime`, `startDate`, `closedDate`, `lastModifiedDate`, `alarmType`,
/// `assignedEngineer`, `lastModifiedBy` - are present with a mix of nulls and
/// real values so the regression pins their nullability too.
const Map<String, dynamic> kLiveIncidentDetailsData = {
  'id': 26,
  'incidentNo': 'INC-SEED-D10739-04',
  'title': 'Test Incident - D10739',
  'description': 'Seeded sample incident (Need Assign) for location D10739',
  'alarmId': '1',
  'alarmName': 'test',
  'productName': null,
  'nativeMoName': null,
  'raisedTime': '2026-09-30T14:22:14',
  'clearedTime': null,
  'createdDate': '2026-09-30T14:22:14',
  'startDate': '2026-09-30T14:22:14',
  'closedDate': null,
  'lastModifiedDate': '2026-09-11T23:31:26.983',
  'alarmType': {'id': 1, 'name': 'X2 Interface Fault'},
  'incidentType': {'id': 1, 'name': 'X2 Interface Fault'},
  'priority': {'id': 1, 'name': 'High'},
  'status': {'id': 3, 'name': 'Pending'},
  'notificationType': {'id': 1, 'name': 'manual'},
  'assignedEngineer': {'id': 4099, 'name': 'engineer 1'},
  'lastModifiedBy': {'id': 4099, 'name': 'engineer 1'},
  'location': {
    'id': 'D10739',
    'name': 'site b2',
    'region': {'id': 81, 'name': 'Giza'},
    'area': {'id': 90, 'name': 'El Ayat'},
    'latitude': 31.345689615304693,
    'longitude': 30.056498596656265,
  },
};

/// Verbatim `data` payload of `CAP/CapIncident/GetIncidentRequests`.
const Map<String, dynamic> kIncidentRequestsData = {
  'incidentId': 1,
  'incidentNo': 'INC-0001',
  'items': [
    {
      'id': 1,
      'requestType': {'id': 1, 'name': 'Intervention Request'},
      'requestStatus': {'id': 2, 'name': 'Approved'},
      'remark': 'test',
      'createdDate': '2026-09-05T00:00:00',
      'createdBy': {'id': 4089, 'name': 'offline user'},
      'lastModifiedBy': {'id': 4098, 'name': 'gsm manager'},
      'lastModifiedDate': '2026-09-06T23:37:17.22',
    },
    {
      'id': 2,
      'requestType': {'id': 2, 'name': 'Renewal Request'},
      'requestStatus': {'id': 3, 'name': 'Rejected'},
      'remark': 'test',
      'createdDate': '2026-09-05T00:00:00',
      'createdBy': {'id': 4089, 'name': 'offline user'},
      'lastModifiedBy': {'id': 4098, 'name': 'gsm manager'},
      'lastModifiedDate': '2026-09-07T01:33:42.047',
    },
  ],
};

/// Builds the shared CAP envelope around [data].
Map<String, dynamic> capBody(Object data) => CapRequest<Object>(
  userId: 4098,
  deviceIdentifier: 'FUH0216913004222',
  deviceToken: '',
  osVersion: '15.1',
  appVersion: '1',
  deviceType: 'iOS',
  data: data as dynamic,
).toJson();

void main() {
  group('request bodies use exact CAP casing', () {
    test('GetIncidentDetails sends IncidentId and IncidentNo', () {
      final body = IncidentDetailsRequestData(
        incidentId: 26,
        incidentNo: '',
      ).toJson();

      expect(body, {'IncidentId': 26, 'IncidentNo': ''});
      expect(() => jsonEncode(body), returnsNormally);
    });

    test('GetIncidentDetails keeps a supplied IncidentNo', () {
      final body = IncidentDetailsRequestData(
        incidentId: 26,
        incidentNo: 'INC-SEED-D10739-04',
      ).toJson();

      expect(body, {'IncidentId': 26, 'IncidentNo': 'INC-SEED-D10739-04'});
    });

    test('GetIncidentTimeline sends only IncidentId', () {
      final body = IncidentTimelineRequestData(incidentId: 26).toJson();

      expect(body, {'IncidentId': 26});
      expect(() => jsonEncode(body), returnsNormally);
    });

    test('GetIncidentRequests sends only IncidentId', () {
      final body = IncidentRequestsRequestData(incidentId: 1).toJson();

      expect(body, {'IncidentId': 1});
      expect(() => jsonEncode(body), returnsNormally);
    });

    test('no request DTO leaks "Instance of" into the JSON', () {
      for (final body in [
        IncidentDetailsRequestData(incidentId: 26).toJson(),
        IncidentTimelineRequestData(incidentId: 26).toJson(),
        IncidentRequestsRequestData(incidentId: 1).toJson(),
      ]) {
        expect(jsonEncode(body), isNot(contains('Instance of')));
      }
    });
  });

  group('CAP envelope serializes the nested payload', () {
    test('details request survives jsonEncode inside the envelope', () {
      final envelope = capBody(IncidentDetailsRequestData(incidentId: 26));

      expect(() => jsonEncode(envelope), returnsNormally);
      expect(envelope['data'], {'IncidentId': 26, 'IncidentNo': ''});
      expect(jsonDecode(jsonEncode(envelope))['data'], {
        'IncidentId': 26,
        'IncidentNo': '',
      });
      expect(envelope['userid'], 4098);
      expect(envelope['devicetype'], 'iOS');
    });

    test('timeline and related-requests payloads stay encodable', () {
      for (final payload in <CapPayload>[
        IncidentTimelineRequestData(incidentId: 26),
        IncidentRequestsRequestData(incidentId: 1),
      ]) {
        final envelope = capBody(payload);
        expect(() => jsonEncode(envelope), returnsNormally);
        expect(envelope['data'], isA<Map<String, dynamic>>());
      }
    });
  });

  group('GetIncidentDetails response', () {
    test('parses every field of the real payload', () {
      final data = IncidentDetailsData.fromJson(kIncidentDetailsData);

      expect(data.id, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
      expect(data.title, 'Test Incident - D10739');
      expect(
        data.description,
        'Seeded sample incident (Need Assign) for location D10739',
      );
      expect(data.alarmId, isNull);
      expect(data.alarmName, 'test');
      expect(data.productName, isNull);
      expect(data.nativeMoName, isNull);
      expect(data.raisedTime, '2026-09-30T14:22:14');
      expect(data.clearedTime, isNull);
      expect(data.createdDate, '2026-09-30T14:22:14');
      expect(data.startDate, '2026-09-30T14:22:14');
      expect(data.closedDate, isNull);
      expect(data.lastModifiedDate, '2026-09-11T23:31:26.983');
    });

    test('parses the nested id/name blocks', () {
      final data = IncidentDetailsData.fromJson(kIncidentDetailsData);

      expect(data.alarmType?.id, 1);
      expect(data.alarmType?.name, 'X2 Interface Fault');
      expect(data.incidentType?.name, 'X2 Interface Fault');
      expect(data.priority?.id, 1);
      expect(data.priority?.name, 'High');
      expect(data.status?.id, 3);
      expect(data.status?.name, 'Pending');
      expect(data.notificationType?.id, 1);
      expect(data.notificationType?.name, 'manual');
      expect(data.assignedEngineer?.id, 4099);
      expect(data.assignedEngineer?.name, 'engineer 1');
      expect(data.lastModifiedBy?.id, 4099);
      expect(data.lastModifiedBy?.name, 'engineer 1');
    });

    test('parses the location block including the string site code', () {
      final location = IncidentDetailsData.fromJson(
        kIncidentDetailsData,
      ).location!;

      expect(location.id, 'D10739');
      expect(location.name, 'site b2');
      expect(location.region?.id, 81);
      expect(location.region?.name, 'Giza');
      expect(location.area?.id, 90);
      expect(location.area?.name, 'El Ayat');
      expect(location.latitude, closeTo(31.345689615304693, 1e-12));
      expect(location.longitude, closeTo(30.056498596656265, 1e-12));
    });

    test('tolerates a payload with only an id', () {
      final data = IncidentDetailsData.fromJson({'id': 26});

      expect(data.id, 26);
      expect(data.location, isNull);
      expect(data.priority, isNull);
    });
  });

  group('GetIncidentRequests response', () {
    test('parses the incident header and both items', () {
      final data = IncidentRequestsData.fromJson(kIncidentRequestsData);

      expect(data.incidentId, 1);
      expect(data.incidentNo, 'INC-0001');
      expect(data.items?.length, 2);
      expect(data.items?.first.id, 1);
      expect(data.items?.last.id, 2);
    });

    test('parses the nested request blocks', () {
      final items = IncidentRequestsData.fromJson(kIncidentRequestsData).items!;

      final first = items.first;
      expect(first.requestType?.id, 1);
      expect(first.requestType?.name, 'Intervention Request');
      expect(first.requestStatus?.id, 2);
      expect(first.requestStatus?.name, 'Approved');
      expect(first.remark, 'test');
      expect(first.createdDate, '2026-09-05T00:00:00');
      expect(first.createdBy?.id, 4089);
      expect(first.createdBy?.name, 'offline user');
      expect(first.lastModifiedBy?.id, 4098);
      expect(first.lastModifiedBy?.name, 'gsm manager');
      expect(first.lastModifiedDate, '2026-09-06T23:37:17.22');

      final second = items.last;
      expect(second.requestType?.name, 'Renewal Request');
      expect(second.requestStatus?.name, 'Rejected');
      expect(second.lastModifiedDate, '2026-09-07T01:33:42.047');
    });

    test('an incident with no requests yields a null list', () {
      final data = IncidentRequestsData.fromJson({'incidentId': 1});

      expect(data.items, isNull);
    });
  });

  group('GetIncidentTimeline response', () {
    test('parses the exact payload the backend returned', () {
      final data = IncidentTimelineData.fromJson(kTimelineDataJson);

      expect(data.incidentId, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
      expect(data.events, hasLength(2));

      final first = data.events![0];
      expect(first.dateTime, '2026-09-11T23:24:31.963');
      expect(first.actionType!.id, 1);
      expect(first.actionType!.name, 'Assign');
      expect(first.eventType, 'Assign');
      expect(first.eventTitle, 'Incident Assigned');
      expect(
        first.eventDescription,
        'Incident assigned to engineer 1 — status changed to Need Approval',
      );
      expect(first.oldValue!.name, 'Need Assign');
      expect(first.newValue!.name, 'Need Approval');
      expect(first.referenceId, isNull);
      expect(first.performedBy!.id, 4098);
      expect(first.performedBy!.name, 'gsm manager');

      final second = data.events![1];
      expect(second.dateTime, '2026-09-11T23:31:26.983');
      expect(second.actionType!.name, 'Approve');
      expect(second.eventType, 'StatusChange');
      expect(second.eventTitle, 'Incident Status Changed');
      expect(second.oldValue!.name, 'Need Approval');
      expect(second.newValue!.name, 'Pending');
      expect(second.referenceId, isNull);
      expect(second.performedBy!.name, 'engineer 1');
    });

    test('keeps events in the order the API returned them', () {
      final data = IncidentTimelineData.fromJson(kTimelineDataJson);

      // The payload arrives chronological ascending; nothing may re-order it.
      expect(data.events!.map((event) => event.eventTitle), [
        'Incident Assigned',
        'Incident Status Changed',
      ]);
    });

    test('an empty event list is a valid payload', () {
      final data = IncidentTimelineData.fromJson(const {
        'incidentId': 26,
        'incidentNo': 'INC-SEED-D10739-04',
        'events': <Map<String, dynamic>>[],
      });

      expect(data.events, isEmpty);
      expect(data.incidentId, 26);
    });

    test('a missing events key stays null rather than throwing', () {
      final data = IncidentTimelineData.fromJson(const {'incidentId': 26});

      expect(data.events, isNull);
      expect(data.incidentNo, isNull);
    });

    test('an event with every optional field null parses safely', () {
      final data = IncidentTimelineData.fromJson(const {
        'incidentId': 26,
        'events': [
          {'dateTime': '2026-09-11T23:24:31.963', 'referenceId': null},
        ],
      });

      final event = data.events!.single;
      expect(event.actionType, isNull);
      expect(event.eventTitle, isNull);
      expect(event.eventDescription, isNull);
      expect(event.oldValue, isNull);
      expect(event.newValue, isNull);
      expect(event.performedBy, isNull);
      expect(event.referenceId, isNull);
    });

    test('referenceId accepts an unexpected scalar without crashing', () {
      // Only null is proven by the payload, so the field stays untyped and must
      // survive whatever shape turns up later.
      for (final value in <Object?>[null, 7, 'REQ-1', 3.5]) {
        final data = IncidentTimelineData.fromJson({
          'events': [
            {'referenceId': value},
          ],
        });
        expect(data.events!.single.referenceId, value);
      }
    });

    test('round-trips through JSON like the wire does', () {
      final json = IncidentTimelineData.fromJson(kTimelineDataJson).toJson();

      expect(json['incidentId'], 26);
      expect(json['incidentNo'], 'INC-SEED-D10739-04');
      expect(json['events'], hasLength(2));
      // jsonEncode walks the nested DTOs through their own toJson.
      expect(jsonEncode(json), isNot(contains('Instance of')));

      // Decoded back from the encoded form, as a real request would be.
      final again = IncidentTimelineData.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(again.incidentId, 26);
      expect(again.incidentNo, 'INC-SEED-D10739-04');
      expect(again.events, hasLength(2));
      expect(again.events!.first.eventTitle, 'Incident Assigned');
      expect(again.events!.first.performedBy!.name, 'gsm manager');
      expect(again.events!.first.oldValue!.name, 'Need Assign');
      expect(again.events!.first.newValue!.name, 'Need Approval');
      expect(again.events!.first.referenceId, isNull);
    });
  });

  group('live GetIncidentDetails response', () {
    test('parses the exact live payload, alarmId included', () {
      // Regression: this threw
      // `type 'String' is not a subtype of type 'num?'` before alarmId became a
      // String-typed identifier.
      expect(
        () => IncidentDetailsData.fromJson(kLiveIncidentDetailsData),
        returnsNormally,
      );

      final data = IncidentDetailsData.fromJson(kLiveIncidentDetailsData);
      expect(data.alarmId, '1');
      expect(data.id, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
      expect(data.title, 'Test Incident - D10739');
      expect(data.alarmName, 'test');
      expect(data.status!.name, 'Pending');
      expect(data.location!.id, 'D10739');
    });

    test('every reviewed optional field is nullable in the DTO', () {
      // Each of these is declared `?`; assigning null is the assertion.
      const data = IncidentDetailsData(
        nativeMoName: null,
        clearedTime: null,
        startDate: null,
        closedDate: null,
        lastModifiedDate: null,
        alarmType: null,
        assignedEngineer: null,
        lastModifiedBy: null,
        alarmId: null,
      );

      expect(data.nativeMoName, isNull);
      expect(data.clearedTime, isNull);
      expect(data.startDate, isNull);
      expect(data.closedDate, isNull);
      expect(data.lastModifiedDate, isNull);
      expect(data.alarmType, isNull);
      expect(data.assignedEngineer, isNull);
      expect(data.lastModifiedBy, isNull);
      expect(data.alarmId, isNull);
    });

    test('the reviewed fields survive nulls in the live payload', () {
      final data = IncidentDetailsData.fromJson(kLiveIncidentDetailsData);

      // Null in the payload, present as a null field.
      expect(data.productName, isNull);
      expect(data.nativeMoName, isNull);
      expect(data.clearedTime, isNull);
      expect(data.closedDate, isNull);

      // Non-null siblings confirm the parse did not just zero everything.
      expect(data.startDate, '2026-09-30T14:22:14');
      expect(data.lastModifiedDate, '2026-09-11T23:31:26.983');
      expect(data.alarmType!.name, 'X2 Interface Fault');
      expect(data.assignedEngineer!.name, 'engineer 1');
      expect(data.lastModifiedBy!.name, 'engineer 1');
    });

    test('every reviewed field also accepts an explicit null', () {
      // A payload that nulls the blocks the live response populated must not
      // throw, since those are the same fields.
      final data = IncidentDetailsData.fromJson(const {
        'alarmId': null,
        'nativeMoName': null,
        'clearedTime': null,
        'startDate': null,
        'closedDate': null,
        'lastModifiedDate': null,
        'alarmType': null,
        'assignedEngineer': null,
        'lastModifiedBy': null,
      });

      expect(data.alarmId, isNull);
      expect(data.nativeMoName, isNull);
      expect(data.clearedTime, isNull);
      expect(data.startDate, isNull);
      expect(data.closedDate, isNull);
      expect(data.lastModifiedDate, isNull);
      expect(data.alarmType, isNull);
      expect(data.assignedEngineer, isNull);
      expect(data.lastModifiedBy, isNull);
    });
  });

  group('CapIdentifierConverter', () {
    test('normalizes both wire forms of an identifier to String', () {
      // The live backend sent a string; sibling numeric ids arrive as numbers.
      // The DTO must survive either without a contract change.
      expect(CapIdentifierConverter.decode('1'), '1');
      expect(CapIdentifierConverter.decode(1), '1');
      expect(CapIdentifierConverter.decode(0), '0');
      expect(CapIdentifierConverter.decode(null), isNull);
    });

    test('keeps a non-numeric identifier intact', () {
      expect(CapIdentifierConverter.decode('ALM-2026-0042'), 'ALM-2026-0042');
      expect(CapIdentifierConverter.decode('0'), '0');
    });

    test('decodes a value that is not an identifier as null, not a throw', () {
      // A malformed field must not take down the whole screen.
      expect(CapIdentifierConverter.decode(true), isNull);
      expect(CapIdentifierConverter.decode({'id': 1}), isNull);
      expect(CapIdentifierConverter.decode(<String>[]), isNull);
    });

    test('round-trips through the full DTO for both wire forms', () {
      for (final wire in const ['1', 1]) {
        final data = IncidentDetailsData.fromJson({
          ...kLiveIncidentDetailsData,
          'alarmId': wire,
        });
        expect(data.alarmId, '1', reason: 'wire form $wire');

        final json = data.toJson();
        expect(json['alarmId'], '1');
        expect(
          () => jsonEncode(json),
          returnsNormally,
          reason: 'no "Instance of" leaks on the wire form $wire',
        );
        expect(jsonEncode(json), isNot(contains('Instance of')));
      }
    });

    test('a live-shaped payload survives encode and decode again', () {
      final json = IncidentDetailsData.fromJson(
        kLiveIncidentDetailsData,
      ).toJson();

      final again = IncidentDetailsData.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(again.alarmId, '1');
      expect(again.incidentNo, 'INC-SEED-D10739-04');
      expect(again.location!.region!.name, 'Giza');
      expect(again.clearedTime, isNull);
    });
  });
}
