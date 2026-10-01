import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_details_repository_impl.dart';

import 'support/timeline_fixtures.dart';

/// Serves one canned CAP envelope, or rethrows a configured [DioException], so
/// repository behaviour can be observed without touching the network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.body, this.status = 200, this.error});

  final Object? body;
  final int status;
  final DioException? error;

  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;

  /// The `data` object as it would be serialized on the wire.
  Map<String, dynamic> get lastData =>
      jsonDecode(jsonEncode(lastRequest.data)) as Map<String, dynamic>;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Mirrors Dio's real request transform so an unserializable CAP payload
    // fails here instead of silently reaching the adapter.
    jsonEncode(options.data);
    if (error != null) throw error!;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = true}) {}
}

class _FixedUsers implements SessionUserStorage {
  _FixedUsers(this.user);
  final SessionUser? user;
  @override
  Future<void> clearUser() async {}
  @override
  Future<SessionUser?> readUser() async => user;
  @override
  Future<void> writeUser(SessionUser value) async {}
}

/// The exact `data` payload of a real `GetIncidentDetails` response.
const Map<String, dynamic> kDetailsData = {
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

/// The LIVE `data` payload: identical to [kDetailsData] except `alarmId` is the
/// JSON string `"1"` the backend actually sent.
///
/// Not `const`, because a const map literal rejects the duplicate `alarmId` key
/// the spread introduces; in a mutable literal the later entry wins.
final Map<String, dynamic> kLiveDetailsData = {...kDetailsData, 'alarmId': '1'};

/// The exact `data` payload of a real `GetIncidentRequests` response.
const Map<String, dynamic> kRequestsData = {
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

Map<String, dynamic> capSuccess(Object? data) => {
  'resultcode': 1,
  'resultmessages': {'resultmessageen': 'OK', 'resultmessagear': 'تم'},
  'data': data,
};

void main() {
  ApiRequestContextProvider contextWith(SessionUser? user) =>
      ApiRequestContextProvider(
        users: _FixedUsers(user),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      );

  IncidentDetailsRepositoryImpl repositoryWith(_StubAdapter adapter) =>
      IncidentDetailsRepositoryImpl(
        IncidentApiService(
          Dio(BaseOptions(baseUrl: 'https://cap.test/v1'))
            ..httpClientAdapter = adapter,
        ),
        contextWith(const SessionUser(id: '4098', name: 'Engineer')),
      );

  group('A. getIncidentDetails success', () {
    late _StubAdapter adapter;
    late IncidentDetailsRepositoryImpl repository;

    setUp(() {
      adapter = _StubAdapter(body: capSuccess(kDetailsData));
      repository = repositoryWith(adapter);
    });

    test('calls the details endpoint exactly once', () async {
      await repository.getIncidentDetails(incidentId: 26, incidentNo: '');

      expect(adapter.requests.length, 1);
      expect(adapter.lastRequest.path, 'CAP/CapIncident/GetIncidentDetails');
      expect(adapter.lastRequest.baseUrl, 'https://cap.test/v1');
    });

    test('sends IncidentId and IncidentNo inside the CAP envelope', () async {
      await repository.getIncidentDetails(incidentId: 26, incidentNo: '');

      expect(adapter.lastData['data'], {'IncidentId': 26, 'IncidentNo': ''});
    });

    test('builds the envelope from the shared request context', () async {
      await repository.getIncidentDetails(incidentId: 26, incidentNo: '');

      // Session/device metadata must come from the context provider, never be
      // hardcoded per call.
      expect(adapter.lastData['userid'], 4098);
      expect(adapter.lastData['devicetype'], 'iOS');
      expect(adapter.lastData['osversion'], '15.1');
      expect(adapter.lastData['AppVersion'], '1');
      expect(adapter.lastData.containsKey('ipaddress'), isTrue);
      expect(adapter.lastData.containsKey('devicetoken'), isTrue);
    });

    test('returns the parsed incident', () async {
      final result = await repository.getIncidentDetails(
        incidentId: 26,
        incidentNo: '',
      );

      expect(result, isA<Success<IncidentDetailsData>>());
      final data = (result as Success<IncidentDetailsData>).data;
      expect(data.id, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
      expect(data.title, 'Test Incident - D10739');
      expect(data.status?.name, 'Pending');
      expect(data.priority?.name, 'High');
      expect(data.location?.id, 'D10739');
      expect(data.assignedEngineer?.name, 'engineer 1');
    });

    test('passes a supplied IncidentNo through unchanged', () async {
      await repository.getIncidentDetails(
        incidentId: 26,
        incidentNo: 'INC-SEED-D10739-04',
      );

      expect(adapter.lastData['data'], {
        'IncidentId': 26,
        'IncidentNo': 'INC-SEED-D10739-04',
      });
    });
  });

  group('B. getIncidentRequests success', () {
    late _StubAdapter adapter;
    late IncidentDetailsRepositoryImpl repository;

    setUp(() {
      adapter = _StubAdapter(body: capSuccess(kRequestsData));
      repository = repositoryWith(adapter);
    });

    test('calls the requests endpoint once with IncidentId', () async {
      final result = await repository.getIncidentRequests(incidentId: 1);

      expect(adapter.requests.length, 1);
      expect(adapter.lastRequest.path, 'CAP/CapIncident/GetIncidentRequests');
      expect(adapter.lastData['data'], {'IncidentId': 1});
      expect(result, isA<Success<IncidentRequestsData>>());
    });

    test('returns both items with their statuses', () async {
      final result = await repository.getIncidentRequests(incidentId: 1);
      final data = (result as Success<IncidentRequestsData>).data;

      expect(data.incidentId, 1);
      expect(data.incidentNo, 'INC-0001');
      expect(data.items?.length, 2);
      expect(data.items!.first.requestStatus?.name, 'Approved');
      expect(data.items!.last.requestStatus?.name, 'Rejected');
      expect(data.items!.first.requestType?.name, 'Intervention Request');
      expect(data.items!.last.requestType?.name, 'Renewal Request');
    });
  });

  group('A2. live response contract', () {
    test('a string alarmId decodes instead of failing the request', () async {
      // Regression: the live response sent `"alarmId": "1"`, which the generated
      // `(json['alarmId'] as num?)` cast rejected. A contract mismatch must fail
      // the call, not crash the app.
      final adapter = _StubAdapter(body: capSuccess(kLiveDetailsData));

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: 'INC-SEED-D10739-04');

      expect(result, isA<Success<IncidentDetailsData>>());
      final data = (result as Success).data as IncidentDetailsData;
      expect(data.alarmId, '1');
      expect(data.id, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
    });

    test('a numeric alarmId decodes to the same value', () async {
      // The sibling numeric ids arrive as numbers, so both forms must work
      // against the one field.
      final adapter = _StubAdapter(
        body: capSuccess({...kDetailsData, 'alarmId': 1}),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: 'INC-SEED-D10739-04');

      expect(((result as Success).data as IncidentDetailsData).alarmId, '1');
    });

    test('a null alarmId still decodes as null', () async {
      final adapter = _StubAdapter(body: capSuccess(kDetailsData));

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: 'INC-SEED-D10739-04');

      expect(((result as Success).data as IncidentDetailsData).alarmId, isNull);
    });
  });

  group('C. empty related requests is a success', () {
    test('items: [] succeeds with an empty list', () async {
      final adapter = _StubAdapter(
        body: capSuccess({
          'incidentId': 1,
          'incidentNo': 'INC-0001',
          'items': <Map<String, dynamic>>[],
        }),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentRequests(incidentId: 1);

      expect(result, isA<Success<IncidentRequestsData>>());
      final data = (result as Success<IncidentRequestsData>).data;
      expect(data.items, isEmpty);
      expect(data.incidentNo, 'INC-0001');
    });
  });

  group('D. CAP failure', () {
    test('resultcode 0 returns the backend message as a failure', () async {
      final adapter = _StubAdapter(
        body: {
          'resultcode': 0,
          'resultmessages': {
            'resultmessageen': 'Failed',
            'resultmessagear': 'فشل',
          },
          'data': null,
        },
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect(result, isA<FailureResult<IncidentDetailsData>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ServiceFailure>());
    });

    test(
      'keeps the English backend message when English is selected',
      () async {
        CapLocaleHolder.instance.update(const Locale('en'));
        addTearDown(() => CapLocaleHolder.instance.update(const Locale('ar')));
        final adapter = _StubAdapter(
          body: {
            'resultcode': 0,
            'resultmessages': {
              'resultmessageen': 'Failed',
              'resultmessagear': 'فشل',
            },
            'data': null,
          },
        );

        final result = await repositoryWith(
          adapter,
        ).getIncidentDetails(incidentId: 26, incidentNo: '');

        expect((result as FailureResult).failure.message, 'Failed');
      },
    );

    test('keeps the Arabic backend message when Arabic is selected', () async {
      CapLocaleHolder.instance.update(const Locale('ar'));
      final adapter = _StubAdapter(
        body: {
          'resultcode': 0,
          'resultmessages': {
            'resultmessageen': 'Failed',
            'resultmessagear': 'فشل',
          },
          'data': null,
        },
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect((result as FailureResult).failure.message, 'فشل');
    });

    test('preserves the backend message instead of a generic one', () async {
      CapLocaleHolder.instance.update(const Locale('en'));
      addTearDown(() => CapLocaleHolder.instance.update(const Locale('ar')));
      final adapter = _StubAdapter(
        body: {
          'resultcode': 0,
          'resultmessages': {
            'resultmessageen': 'Incident not found',
            'resultmessagear': 'البلاغ غير موجود',
          },
          'data': null,
        },
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect((result as FailureResult).failure.message, 'Incident not found');
    });

    test('resultcode 0 also fails the requests call', () async {
      final adapter = _StubAdapter(
        body: {
          'resultcode': 0,
          'resultmessages': {'resultmessageen': 'Failed'},
          'data': null,
        },
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentRequests(incidentId: 1);

      expect(result, isA<FailureResult<IncidentRequestsData>>());
    });
  });

  group('E. network failure', () {
    test('connection error maps to NetworkFailure', () async {
      final adapter = _StubAdapter(
        body: null,
        error: DioException(
          requestOptions: RequestOptions(
            path: 'CAP/CapIncident/GetIncidentDetails',
          ),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect(result, isA<FailureResult<IncidentDetailsData>>());
      expect((result as FailureResult).failure, isA<NetworkFailure>());
    });

    test('receive timeout maps to TimeoutFailure', () async {
      final adapter = _StubAdapter(
        body: null,
        error: DioException(
          requestOptions: RequestOptions(
            path: 'CAP/CapIncident/GetIncidentRequests',
          ),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentRequests(incidentId: 1);

      expect((result as FailureResult).failure, isA<TimeoutFailure>());
    });

    test('HTTP 500 maps to ServerFailure', () async {
      final adapter = _StubAdapter(body: capSuccess(null), status: 500);

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect((result as FailureResult).failure, isA<ServerFailure>());
    });
  });

  group('F. missing data is never fabricated', () {
    test('details: success code with null data fails', () async {
      final adapter = _StubAdapter(body: capSuccess(null));

      final result = await repositoryWith(
        adapter,
      ).getIncidentDetails(incidentId: 26, incidentNo: '');

      expect(result, isA<FailureResult<IncidentDetailsData>>());
      expect((result as FailureResult).failure, isA<ServiceFailure>());
    });

    test('requests: success code with null data fails', () async {
      final adapter = _StubAdapter(body: capSuccess(null));

      final result = await repositoryWith(
        adapter,
      ).getIncidentRequests(incidentId: 1);

      expect(result, isA<FailureResult<IncidentRequestsData>>());
    });

    test('timeline: success code with null data fails', () async {
      final adapter = _StubAdapter(body: capSuccess(null));

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<FailureResult<IncidentTimelineData>>());
    });
  });

  group('G. getIncidentTimeline', () {
    test('sends IncidentId and calls the timeline endpoint once', () async {
      final adapter = _StubAdapter(body: capSuccess(kTimelineDataJson));

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(adapter.requests.length, 1);
      expect(adapter.lastRequest.path, 'CAP/CapIncident/GetIncidentTimeline');
      // The id comes from the caller, never from a literal in the repository.
      expect(adapter.lastData['data'], {'IncidentId': 26});
      expect(adapter.lastData['userid'], 4098);
      expect(result, isA<Success<IncidentTimelineData>>());
    });

    test('sends the incident id it is given, not a fixed one', () async {
      final adapter = _StubAdapter(body: capSuccess(kTimelineDataJson));

      await repositoryWith(adapter).getIncidentTimeline(incidentId: 7788);

      expect(adapter.lastData['data'], {'IncidentId': 7788});
    });

    test('parses the real payload into typed events', () async {
      final adapter = _StubAdapter(body: capSuccess(kTimelineDataJson));

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      final data = (result as Success).data as IncidentTimelineData;
      expect(data.incidentId, 26);
      expect(data.incidentNo, 'INC-SEED-D10739-04');
      expect(data.events, hasLength(2));

      final first = data.events!.first;
      expect(first.dateTime, '2026-09-11T23:24:31.963');
      expect(first.actionType!.name, 'Assign');
      expect(first.eventType, 'Assign');
      expect(first.eventTitle, 'Incident Assigned');
      expect(
        first.eventDescription,
        'Incident assigned to engineer 1 — status changed to Need Approval',
      );
      expect(first.oldValue!.name, 'Need Assign');
      expect(first.newValue!.name, 'Need Approval');
      expect(first.performedBy!.name, 'gsm manager');
      expect(first.referenceId, isNull);
    });

    test('an empty events list is a success, not a failure', () async {
      final adapter = _StubAdapter(
        body: capSuccess(<String, dynamic>{
          'incidentId': 26,
          'incidentNo': 'INC-SEED-D10739-04',
          'events': <Map<String, dynamic>>[],
        }),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<Success<IncidentTimelineData>>());
      expect(
        ((result as Success).data as IncidentTimelineData).events,
        isEmpty,
      );
    });

    test('a null data block fails', () async {
      final adapter = _StubAdapter(body: capSuccess(null));

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<FailureResult<IncidentTimelineData>>());
    });

    test('a non-object data block decodes to empty rather than throwing', () async {
      // `capMap` yields `{}` for anything that is not a map, so the typed decode
      // produces an all-null payload. This is the existing project-wide
      // convention (General and Related Requests decode identically) and keeps a
      // surprising backend value from crashing the tab.
      final adapter = _StubAdapter(body: capSuccess('not-an-object'));

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<Success<IncidentTimelineData>>());
      final data = (result as Success).data as IncidentTimelineData;
      expect(data.incidentId, isNull);
      expect(data.events, isNull);
    });

    test('an event with null optional fields still parses', () async {
      final adapter = _StubAdapter(
        body: capSuccess(<String, dynamic>{
          'incidentId': 26,
          'events': [
            {'dateTime': '2026-09-11T23:24:31.963', 'referenceId': null},
          ],
        }),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      final data = (result as Success).data as IncidentTimelineData;
      final event = data.events!.single;
      expect(event.eventTitle, isNull);
      expect(event.performedBy, isNull);
      expect(event.referenceId, isNull);
    });

    test('a CAP failure surfaces as a failure', () async {
      final adapter = _StubAdapter(
        body: {
          'resultcode': 0,
          'resultmessages': {'resultmessageen': 'Failed'},
          'data': null,
        },
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<FailureResult<IncidentTimelineData>>());
    });

    test('a Dio failure maps to NetworkFailure', () async {
      final adapter = _StubAdapter(
        body: null,
        error: DioException(
          requestOptions: RequestOptions(
            path: 'CAP/CapIncident/GetIncidentTimeline',
          ),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repositoryWith(
        adapter,
      ).getIncidentTimeline(incidentId: 26);

      expect(result, isA<FailureResult<IncidentTimelineData>>());
      expect((result as FailureResult).failure, isA<NetworkFailure>());
    });

    test('no signed-in user fails before any request is sent', () async {
      final adapter = _StubAdapter(body: capSuccess(kTimelineDataJson));
      final repository = IncidentDetailsRepositoryImpl(
        IncidentApiService(
          Dio(BaseOptions(baseUrl: 'https://cap.test/v1'))
            ..httpClientAdapter = adapter,
        ),
        contextWith(null),
      );

      final result = await repository.getIncidentTimeline(incidentId: 26);

      expect(result, isA<FailureResult<IncidentTimelineData>>());
      expect(adapter.requests, isEmpty);
    });
  });

  group('H. session guard', () {
    test('no signed-in user fails before any request is sent', () async {
      final adapter = _StubAdapter(body: capSuccess(kDetailsData));
      final repository = IncidentDetailsRepositoryImpl(
        IncidentApiService(
          Dio(BaseOptions(baseUrl: 'https://cap.test/v1'))
            ..httpClientAdapter = adapter,
        ),
        contextWith(null),
      );

      final result = await repository.getIncidentDetails(
        incidentId: 26,
        incidentNo: '',
      );

      expect((result as FailureResult).failure, isA<UnauthorizedFailure>());
      // The context provider rejects userId == 0, so nothing is sent.
      expect(adapter.requests, isEmpty);
    });
  });
}
