import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/features/periodic_photo/domain/today_in_process_incident_service.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_details_repository_impl.dart';
import 'support/periodic_photo_fakes.dart' show MemoryTokenStorage;
import 'today_in_process_incident_test.dart' show MemoryIncidentStore;

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;
  final requests = <RequestOptions>[];
  Map<String, dynamic> Function(RequestOptions)? respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    requests.add(options);
    // Mirrors what Dio's real adapter does to the request body before sending,
    // so an unserializable payload fails here instead of silently passing.
    jsonEncode(options.data);
    return ResponseBody.fromString(
      jsonEncode(respond?.call(options) ?? body),
      200,
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

/// The exact shape from the CAP GetIncidentList contract.
final _payload = <String, dynamic>{
  'resultcode': 1,
  'resultmessages': {'resultmessageen': 'OK', 'resultmessagear': 'تم'},
  'data': {
    'Data': [
      {
        'incidentId': 9001,
        'latitude': 31.34573068640783,
        'longitude': 30.056509692385522,
        'incidentNo': 'INC-3001',
        'description': 'Fiber degradation on primary link',
        'locationName': 'Site Riyadh 12',
        'areaName': 'Central Area',
        'regionName': 'Riyadh Region',
        'incidentType': 'Transmission',
        'assignedTeam': 'Team Alpha',
        'status': {'id': 3, 'name': 'Pending'},
        'priority': {'id': 1, 'name': 'High'},
      },
      {
        'incidentId': 9002,
        'incidentNo': 'INC-3002',
        'description': 'Power alarm',
        'locationName': 'Site Jeddah 4',
        'areaName': 'West Area',
        'regionName': 'Jeddah Region',
        'incidentType': 'Power',
        'assignedTeam': 'Team Beta',
        'status': {'id': 4, 'name': 'In Process'},
        'priority': {'id': 2, 'name': 'Medium'},
      },
    ],
    'totalCount': 2,
    'page': 1,
    'pageSize': 100,
  },
};

void main() {
  test(
    'list and normal details reads never change action-only work cache',
    () async {
      final now = DateTime(2026, 10, 20, 10);
      final session = SessionManager(MemoryTokenStorage())..startDemo();
      session.user = const SessionUser(id: '4099');
      final cache = TodayInProcessIncidentService(
        session: session,
        store: MemoryIncidentStore(),
        now: () => now,
      );
      addTearDown(() async {
        await cache.dispose();
        await session.dispose();
      });
      final adapter = _StubAdapter({});
      var failSecondPage = false;
      adapter.respond = (options) {
        if (options.path.endsWith('GetIncidentDetails')) {
          return {
            'resultcode': 1,
            'data': {
              'id': 1,
              'status': {'id': 7},
            },
          };
        }
        final page = ((options.data as Map)['data'] as Map)['Page'] as int;
        return {
          'resultcode': failSecondPage && page == 2 ? 0 : 1,
          'data': {
            'items': [
              {
                'incidentId': page,
                'incidentNo': 'INC-$page',
                'status': {'id': 4},
                'currentUser': {'id': 4099},
                'startDate': '2026-10-20T0${page + 7}:00:00',
              },
            ],
            'totalCount': 2,
            'page': page,
            'pageSize': 1,
          },
        };
      };
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final context = ApiRequestContextProvider(
        users: null,
        currentUser: () => session.user,
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15',
          deviceType: 'Android',
          appVersion: '1',
        ),
      );
      final api = IncidentApiService(dio);
      final repository = IncidentRepositoryImpl(api, context);
      await cache.confirmStatus(1, status: 4, generation: session.generation);
      await repository.getIncidentsForDay(day: now);
      expect(adapter.requests.length, 2);
      expect(cache.incidents.length, 1);
      expect(cache.latest!.id, 1);
      final details = IncidentDetailsRepositoryImpl(api, context);
      await details.getIncidentDetails(incidentId: 1, incidentNo: 'INC-1');
      expect(cache.contains(1), true);
      failSecondPage = true;
      await repository.getIncidentsForDay(day: now);
      expect(
        cache.contains(1),
        true,
        reason: 'list responses never modify locally confirmed work',
      );
      expect(cache.contains(2), false);
    },
  );
  ApiRequestContextProvider contextWith(SessionUser? user) =>
      ApiRequestContextProvider(
        users: _FixedUsers(user),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      );

  test(
    'lookup IDs and manual fields are sent unchanged on every API page',
    () async {
      final adapter = _StubAdapter(_payload);
      adapter.respond = (options) {
        final data =
            (jsonDecode(jsonEncode(options.data)) as Map)['data'] as Map;
        expect(data['IncidentTypeId'], 35);
        expect(data['StatusId'], 8);
        expect(data['PriorityId'], 21);
        expect(data['LocationCode'], 'D10739');
        expect(data['IncidentNo'], 'INC-001');
        expect(data['RegionId'], 81);
        expect(data['AreaId'], 90);
        final page = data['Page'] as int;
        return {
          'resultcode': 1,
          'data': {
            'items': [
              {'incidentId': page},
            ],
            'totalCount': 2,
            'page': page,
            'pageSize': 1,
          },
        };
      };
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repo = IncidentRepositoryImpl(
        IncidentApiService(dio),
        contextWith(const SessionUser(id: '4098')),
      );
      final result = await repo.getIncidentsForDay(
        day: DateTime(2026, 10, 12),
        filter: const IncidentListFilter(
          statusId: 8,
          priorityId: 21,
          incidentTypeId: 35,
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
          incidentNumber: 'INC-001',
        ),
      );
      expect(result, isA<Success<List<CapIncident>>>());
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'range requests use existing paging keys and collect every page',
    () async {
      final adapter = _StubAdapter(_payload);
      adapter.respond = (options) {
        final sent = jsonDecode(jsonEncode(options.data)) as Map;
        final page = (sent['data'] as Map)['Page'] as int;
        expect((sent['data'] as Map)['FromDate'], '2026-09-01');
        expect((sent['data'] as Map)['ToDate'], '2026-09-30');
        expect((sent['data'] as Map)['StatusId'], 407);
        return {
          'resultcode': 1,
          'data': {
            'items': [
              {'incidentId': page, 'incidentNo': 'INC-$page'},
            ],
            'totalCount': 2,
            'page': page,
            'pageSize': 1,
          },
        };
      };
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      final repo = IncidentRepositoryImpl(
        IncidentApiService(dio),
        contextWith(const SessionUser(id: '4098')),
      );
      final result = await repo.getIncidentsForDay(
        day: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 30),
        statusId: 407,
      );
      expect(
        (result as Success<List<CapIncident>>).data.map((i) => i.incidentId),
        [1, 2],
      );
      expect(adapter.requests.length, 2);
    },
  );

  test(
    'repeated server page fails instead of pretending partial list is complete',
    () async {
      final adapter = _StubAdapter({
        'resultcode': 1,
        'data': {
          'items': [
            {'incidentId': 1},
          ],
          'totalCount': 2,
          'page': 1,
        },
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      final repo = IncidentRepositoryImpl(
        IncidentApiService(dio),
        contextWith(const SessionUser(id: '4098')),
      );
      expect(
        await repo.getIncidentsForDay(day: DateTime(2026, 9, 1)),
        isA<FailureResult<List<CapIncident>>>(),
      );
      expect(adapter.requests.length, 2);
    },
  );

  test('GetIncidentList maps the CAP payload into CapIncident list', () async {
    final adapter = _StubAdapter(_payload);
    final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/v1'));
    dio.httpClientAdapter = adapter;

    final repo = IncidentRepositoryImpl(
      IncidentApiService(dio),
      contextWith(const SessionUser(id: '4098', name: 'Engineer')),
    );

    final result = await repo.getIncidentsForDay(day: DateTime(2026, 8, 10));

    expect(result, isA<Success<List<CapIncident>>>());
    final incidents = (result as Success<List<CapIncident>>).data;
    expect(incidents.length, 2, reason: 'payload has 2 incidents');

    final first = incidents.first;
    expect(first.number, 'INC-3001');
    expect(first.title, 'Fiber degradation on primary link');
    expect(first.siteName, 'Site Riyadh 12');
    expect(first.status, CapIncidentStatus.pending);
    expect(first.priority, Priority.high);
    expect(first.latitude, 31.34573068640783);
    expect(first.longitude, 30.056509692385522);
    expect(incidents[1].latitude, isNull);

    expect(incidents[1].status, CapIncidentStatus.inProcess);
    expect(incidents[1].priority, Priority.medium);
  });

  test('parses the live lowercase data.items response', () async {
    // Captured verbatim from CAP; the array key is lowercase `items`.
    final adapter = _StubAdapter({
      'resultcode': 1,
      'resultmessages': {'resultmessageen': 'OK', 'resultmessagear': 'تم'},
      'data': {
        'items': [
          {'incidentId': 26, 'incidentTitle': 'Test Incident - D10739'},
        ],
        'totalCount': 1,
        'page': 1,
        'pageSize': 100,
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/v1'));
    dio.httpClientAdapter = adapter;
    final repo = IncidentRepositoryImpl(
      IncidentApiService(dio),
      contextWith(const SessionUser(id: '4098', name: 'Engineer')),
    );

    final result = await repo.getIncidentsForDay(day: DateTime(2026, 8, 10));

    expect(result, isA<Success<List<CapIncident>>>());
    final incidents = (result as Success<List<CapIncident>>).data;
    expect(incidents.length, 1);
    expect(incidents.first.title, 'Test Incident - D10739');
    // Missing API text must not be replaced with a fabricated incident number.
    expect(incidents.first.number, '');
  });

  test('reads lowercase totalCount, page and pageSize', () {
    final data = IncidentListData.parse({
      'items': [
        {'incidentId': 26, 'incidentTitle': 'Test Incident - D10739'},
      ],
      'totalCount': 1,
      'page': 1,
      'pageSize': 100,
    });

    expect(data.incidents.length, 1);
    expect(data.totalCount, 1);
    expect(data.page, 1);
    expect(data.pageSize, 100);
  });

  test('items takes priority over the legacy fallback keys', () {
    final data = IncidentListData.parse({
      'items': [
        {'incidentId': 1, 'incidentTitle': 'from items'},
      ],
      'Data': [
        {'incidentId': 2, 'incidentTitle': 'from Data'},
      ],
    });

    expect(data.incidents.first.description, 'from items');
  });

  test('request sends today for both bounds and the session userid', () async {
    final adapter = _StubAdapter(_payload);
    final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/v1'));
    dio.httpClientAdapter = adapter;
    final repo = IncidentRepositoryImpl(
      IncidentApiService(dio),
      contextWith(const SessionUser(id: '4098')),
    );
    await repo.getIncidentsForDay(day: DateTime(2026, 8, 10));

    expect(adapter.lastRequest?.path, 'CAP/CapIncident/GetIncidentList');
    expect(adapter.lastRequest?.baseUrl, 'https://cap.test/v1');
    final sent =
        jsonDecode(jsonEncode(adapter.lastRequest!.data))
            as Map<String, dynamic>;
    expect(sent['userid'], 4098);
    expect(sent['AppVersion'], '1');
    expect(sent['devicetype'], 'iOS');
    expect((sent['data'] as Map)['FromDate'], '2026-08-10');
    expect((sent['data'] as Map)['ToDate'], '2026-08-10');
    expect((sent['data'] as Map)['PageSize'], 100);
  });

  test('no signed-in user fails instead of sending userid 0', () async {
    final adapter = _StubAdapter(_payload);
    final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/v1'));
    dio.httpClientAdapter = adapter;

    final repo = IncidentRepositoryImpl(
      IncidentApiService(dio),
      contextWith(null),
    );
    final result = await repo.getIncidentsForDay(day: DateTime(2026, 8, 10));

    expect(result, isA<FailureResult<List<CapIncident>>>());
    expect((result as FailureResult).failure, isA<UnauthorizedFailure>());
    expect(adapter.lastRequest, isNull, reason: 'must not hit the network');
  });
}
