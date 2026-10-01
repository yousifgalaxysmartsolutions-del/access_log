import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/dashboard/data/api/dashboard_api_service.dart';
import 'package:access_log_plus/features/dashboard/data/models/dashboard_stats_models.dart';
import 'package:access_log_plus/features/dashboard/data/repositories/dashboard_repository_impl.dart';

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
    // Mirrors Dio's real request transform, so an unserializable payload fails
    // here instead of silently reaching the adapter.
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

final _payload = <String, dynamic>{
  'resultcode': 1,
  'resultmessages': {'resultmessageen': 'OK', 'resultmessagear': 'تم'},
  'data': {
    'totalIncidents': 48,
    'openIncidents': 12,
    'inProgress': 5,
    'completed': 30,
    'onHold': 1,
    'todaysActivities': 4,
    'needApproval': 2,
    'MonthSummary': {
      'Year': 2026,
      'Month': 8,
      'totalIncident': 48,
      'completed': 30,
      'percentage': 62.5,
    },
  },
};

void main() {
  DashboardRepositoryImpl build(SessionUser? user, _StubAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/v1'))
      ..httpClientAdapter = adapter;
    return DashboardRepositoryImpl(
      DashboardApiService(dio),
      ApiRequestContextProvider(
        users: _FixedUsers(user),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      ),
    );
  }

  test(
    'GetDashboardStats maps every metric and keeps percentage decimal',
    () async {
      final result = await build(
        const SessionUser(id: '4098'),
        _StubAdapter(_payload),
      ).getStats(forMonth: DateTime(2026, 8, 10));

      expect(result, isA<Success<DashboardStatsData>>());
      final stats = (result as Success<DashboardStatsData>).data;
      expect(stats.totalIncidents, 48);
      expect(stats.openIncidents, 12);
      expect(stats.inProgress, 5);
      expect(stats.completed, 30);
      expect(stats.onHold, 1);
      expect(stats.todaysActivities, 4);
      expect(stats.needApproval, 2);
      expect(stats.monthSummary.percentage, 62.5);
    },
  );

  test('request body serializes data with capitalised CAP keys', () async {
    final adapter = _StubAdapter(_payload);
    await build(
      const SessionUser(id: '4098'),
      adapter,
    ).getStats(forMonth: DateTime(2026, 8, 10));

    expect(adapter.lastRequest?.path, 'CAP/CapDashboard/GetDashboardStats');
    final sent =
        jsonDecode(jsonEncode(adapter.lastRequest!.data))
            as Map<String, dynamic>;
    expect(sent['userid'], 4098);
    expect(sent['ipaddress'], isA<String>());
    expect(sent['osversion'], '15.1');
    expect(sent['devicetype'], 'iOS');
    expect(sent['data'], {'Month': 8, 'Year': 2026});
  });

  test(
    'backend failure becomes a ServiceFailure carrying the message',
    () async {
      final adapter = _StubAdapter({
        'resultcode': 0,
        'resultmessages': {
          'resultmessageen': 'Access denied',
          'resultmessagear': 'تم رفض الوصول',
        },
      });
      final result = await build(
        const SessionUser(id: '4098'),
        adapter,
      ).getStats(forMonth: DateTime(2026, 8, 10));

      expect(result, isA<FailureResult<DashboardStatsData>>());
      expect((result as FailureResult).failure.message, isNotEmpty);
    },
  );
}
