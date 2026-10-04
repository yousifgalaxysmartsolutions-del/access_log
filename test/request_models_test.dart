import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/cap/cap_request.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';

const lookupJson = {
  'requestType': [
    {'id': 1, 'name': 'Intervention Request', 'code': 'Intervention'},
    {'id': 2, 'name': 'Renewal Request', 'code': 'Renewal'},
    {'id': 3, 'name': 'Departure Request', 'code': 'Departure'},
  ],
  'requestStatus': [
    {'id': 1, 'name': 'Pending', 'code': 'PENDING'},
    {'id': 2, 'name': 'Approved', 'code': 'APPROVED'},
    {'id': 3, 'name': 'Rejected', 'code': 'REJECTED'},
  ],
  'requestActionType': [
    {'id': 1, 'name': 'Creation', 'code': 'Creation'},
    {'id': 2, 'name': 'Approve', 'code': 'Approve'},
    {'id': 3, 'name': 'Reject', 'code': 'Reject'},
  ],
};

const listJson = {
  'items': [
    {
      'id': 3,
      'incidentId': 3,
      'incidentNo': 'INC-0003',
      'locationCode': 'D10736',
      'locationName': 'site 3',
      'requestType': {'id': 1, 'name': 'Intervention Request'},
      'requestStatus': {'id': 1, 'name': 'Pending'},
      'remark': 'test approve',
      'questionFormId': '1',
      'createdDate': '2026-09-10T00:57:15.38',
      'createdBy': {'id': 4098, 'name': 'gsm manager'},
      'lastModifiedBy': {'id': 4098, 'name': 'gsm manager'},
      'lastModifiedDate': '2026-09-10T00:57:15.38',
    },
    {
      'id': 1,
      'incidentId': 1,
      'incidentNo': 'INC-0001',
      'locationCode': 'D10734',
      'locationName': 'site 1',
      'requestType': {'id': 1, 'name': 'Intervention Request'},
      'requestStatus': {'id': 2, 'name': 'Approved'},
      'remark': 'test',
      'questionFormId': '1085',
      'createdDate': '2026-09-05T00:00:00',
      'createdBy': {'id': 4089, 'name': 'offline user'},
      'lastModifiedBy': {'id': 4098, 'name': 'gsm manager'},
      'lastModifiedDate': '2026-09-06T23:37:17.22',
    },
  ],
  'totalCount': 3,
  'page': 1,
  'pageSize': 2,
};
const listBody = RequestListRequestData(
  fromDate: '2026-09-01',
  toDate: '2026-09-10',
  requestTypeId: -1,
  requestStatusId: -1,
  locationCode: '',
  incidentNo: '',
  page: 1,
  pageSize: 2,
);
const listBodyJson = {
  'FromDate': '2026-09-01',
  'ToDate': '2026-09-10',
  'RequestTypeId': -1,
  'RequestStatusId': -1,
  'LocationCode': '',
  'IncidentNo': '',
  'Page': 1,
  'PageSize': 2,
};
const metadataJson = {
  'userid': 4089,
  'ipaddress': 'FUH0216913004222',
  'devicetoken': 'testtokens',
  'osversion': '15.1',
  'AppVersion': '1',
  'devicetype': 'iOS',
};
CapRequest<T> envelope<T>(T data) => CapRequest<T>(
  userId: 4089,
  deviceIdentifier: 'FUH0216913004222',
  deviceToken: 'testtokens',
  osVersion: '15.1',
  appVersion: '1',
  deviceType: 'iOS',
  data: data,
);
CapRequest<Null> metadataEnvelope() => CapRequest.metadataOnly(
  userId: 4089,
  deviceIdentifier: 'FUH0216913004222',
  deviceToken: 'testtokens',
  osVersion: '15.1',
  appVersion: '1',
  deviceType: 'iOS',
);

void main() {
  test('exact lookup payload round trips all IDs, names and codes', () {
    final data = RequestLookupData.fromJson(lookupJson);
    expect(data.toJson(), lookupJson);
    expect(data.requestType.length, 3);
    expect(data.requestType.first.id, 1);
    expect(data.requestType.first.code, 'Intervention');
    expect(data.requestType.last.id, 3);
    expect(data.requestType.last.name, 'Departure Request');
    expect(data.requestStatus.map((x) => x.name), [
      'Pending',
      'Approved',
      'Rejected',
    ]);
    expect(data.requestActionType.map((x) => x.name), [
      'Creation',
      'Approve',
      'Reject',
    ]);
  });
  test('lookup missing/null lists default empty; unknown values survive', () {
    final data = RequestLookupData.fromJson({'requestType': null});
    expect(data.requestType, isEmpty);
    expect(data.requestStatus, isEmpty);
    expect(data.requestActionType, isEmpty);
    expect(
      RequestLookupItemDto.fromJson({'id': 99, 'code': 'NEW'}).code,
      'NEW',
    );
  });
  test('list payload exact casing and supplied values', () {
    expect(listBody.toJson(), listBodyJson);
    expect(
      RequestListRequestData.fromJson(listBodyJson).toJson(),
      listBodyJson,
    );
  });
  test('exact list response preserves all nested data and timestamps', () {
    final data = RequestListData.fromJson(listJson);
    expect(data.toJson(), listJson);
    expect(data.totalCount, 3);
    expect(data.page, 1);
    expect(data.pageSize, 2);
    expect(data.items.length, 2);
    final first = data.items.first;
    expect(first.id, 3);
    expect(first.incidentId, 3);
    expect(first.incidentNo, 'INC-0003');
    expect(first.locationCode, 'D10736');
    expect(first.requestType?.name, 'Intervention Request');
    expect(first.requestStatus?.name, 'Pending');
    expect(first.questionFormId, '1');
    expect(first.createdBy?.name, 'gsm manager');
    expect(data.items[1].id, 1);
    expect(data.items[1].requestStatus?.name, 'Approved');
    expect(data.items[1].createdBy?.name, 'offline user');
    expect(jsonDecode(jsonEncode(data)), listJson);
  });
  test('nullable item fields and missing items are supported', () {
    final item = RequestListItemDto.fromJson({});
    expect(item.toJson().values.every((value) => value == null), true);
    expect(
      RequestListData.fromJson({
        'totalCount': 0,
        'page': 1,
        'pageSize': 2,
      }).items,
      isEmpty,
    );
  });
  test('approve and reject exact payloads and shared decision response', () {
    expect(
      const RequestApproveData(requestId: 1, remark: 'test approve').toJson(),
      {'RequestId': 1, 'Remark': 'test approve'},
    );
    expect(const RequestRejectData(requestId: 2, reason: 'tst rej').toJson(), {
      'RequestId': 2,
      'Reason': 'tst rej',
    });
    for (final json in [
      {
        'id': 1,
        'requestStatus': {'id': 2, 'name': 'Approved'},
      },
      {
        'id': 2,
        'requestStatus': {'id': 3, 'name': 'Rejected'},
      },
    ]) {
      final result = RequestDecisionData.fromJson(json);
      expect(result.toJson(), json);
      expect(result.requestStatus?.id, (json['requestStatus'] as Map)['id']);
      expect(
        result.requestStatus?.name,
        (json['requestStatus'] as Map)['name'],
      );
    }
  });
  test(
    'all business payloads encode as nested CAP JSON, never object strings',
    () {
      for (final payload in <CapPayload>[
        listBody,
        const RequestApproveData(requestId: 1, remark: 'test approve'),
        const RequestRejectData(requestId: 2, reason: 'tst rej'),
      ]) {
        expect(jsonDecode(jsonEncode(envelope(payload))), {
          ...metadataJson,
          'data': payload.toJson(),
        });
      }
    },
  );
  test(
    'metadata-only opt-in does not alter ordinary null/map/list envelopes',
    () {
      expect(jsonDecode(jsonEncode(metadataEnvelope())), metadataJson);
      for (final data in [
        null,
        <String, dynamic>{},
        {'a': 1},
        [1, 2],
        'text',
        3,
        true,
      ]) {
        expect(jsonDecode(jsonEncode(envelope(data))), {
          ...metadataJson,
          'data': data,
        });
      }
    },
  );
}
