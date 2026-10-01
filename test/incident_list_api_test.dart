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

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    // Mirrors what Dio's real adapter does to the request body before sending,
    // so an unserializable payload fails here instead of silently passing.
    jsonEncode(options.data);
    return ResponseBody.fromString(
      jsonEncode(body),
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
  ApiRequestContextProvider contextWith(SessionUser? user) =>
      ApiRequestContextProvider(
        users: _FixedUsers(user),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
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
    // No incidentNo on the wire, so the mapper falls back to the id.
    expect(incidents.first.number, 'CAP-26');
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
