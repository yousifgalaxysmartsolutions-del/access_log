import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/gps_tracking/data/api/gps_tracking_api_service.dart';
import 'package:access_log_plus/features/gps_tracking/data/models/gps_tracking_sync_payload.dart';
import 'package:access_log_plus/features/gps_tracking/data/repositories/gps_tracking_sync_repository_impl.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_location_record.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  Map<String, dynamic> body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Mirrors Dio's real adapter so an unserializable body fails loudly.
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

ApiRequestContextProvider _context(SessionUser? user) => ApiRequestContextProvider(
  users: _FixedUsers(user),
  deviceInfo: CapDeviceAppInfoProvider(
    osVersion: '15.1',
    deviceType: 'iOS',
    appVersion: '1',
    deviceToken: 'testtokens',
  ),
);

GpsLocationRecord _record(
  String id, {
  bool offline = false,
  double? accuracy,
}) => GpsLocationRecord(
  localId: id,
  locationDateTime: DateTime(2025, 9, 9, 12, 38, 49, 512, 127),
  latitude: 30.0972208,
  longitude: 31.2163613,
  isOffline: offline,
  accuracyMeters: accuracy,
);

void main() {
  group('GpsTrackingSyncRepositoryImpl', () {
    test('sends the CAP envelope and the exact point shape', () async {
      final adapter = _StubAdapter({
        'resultcode': 1,
        'resultmessages': {'resultmessageen': 'OK'},
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      final repository = GpsTrackingSyncRepositoryImpl(
        GpsTrackingApiService(dio),
        _context(const SessionUser(id: '4098')),
      );

      final result = await repository.upload(
        incidentId: 0,
        records: [_record('A', offline: true, accuracy: 5.0)],
      );

      expect(result, isA<Success<bool>>());
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.path, 'CAP/CapAuth/GpsTracking');

      final body = jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
      expect(body['userid'], 4098);
      expect(body['devicetype'], 'iOS');
      expect(body['osversion'], '15.1');
      expect(body['AppVersion'], '1');
      expect(body['devicetoken'], 'testtokens');
      expect(body['ipaddress'], isNotEmpty);

      final data = body['data'] as Map<String, dynamic>;
      expect(data['IncidentId'], 0);
      final points = data['data'] as List;
      expect(points, hasLength(1));
      final point = points.single as Map<String, dynamic>;
      expect(point['LocationDateTime'], '2025-09-09T12:38:49.512127');
      expect(point['TaskLatitude'], '30.0972208');
      expect(point['TaskLongitude'], '31.2163613');
      // Captured offline, uploaded as-is.
      expect(point['isoffline'], isTrue);
      // Local-only fields are never sent.
      expect(point.containsKey('localId'), isFalse);
      expect(point.containsKey('gpsAccuracyMeters'), isFalse);
    });

    test('HTTP 200 with resultcode != 1 is a failure', () async {
      final adapter = _StubAdapter({
        'resultcode': 0,
        'resultmessages': {'resultmessageen': 'Invalid payload'},
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      final repository = GpsTrackingSyncRepositoryImpl(
        GpsTrackingApiService(dio),
        _context(const SessionUser(id: '4098')),
      );

      final result = await repository.upload(
        incidentId: 0,
        records: [_record('A')],
      );

      expect(result, isA<FailureResult<bool>>());
      final failure = (result as FailureResult<bool>).failure;
      expect(failure, isA<ServiceFailure>());
      expect((failure as ServiceFailure).code, 'cap_result_0');
    });

    test('a missing session fails before any request is sent', () async {
      final adapter = _StubAdapter({'resultcode': 1});
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      final repository = GpsTrackingSyncRepositoryImpl(
        GpsTrackingApiService(dio),
        _context(null),
      );

      final result = await repository.upload(
        incidentId: 0,
        records: [_record('A')],
      );

      expect(result, isA<FailureResult<bool>>());
      expect((result as FailureResult<bool>).failure, isA<UnauthorizedFailure>());
      expect(adapter.requests, isEmpty);
    });

    test('an empty batch is a no-op success without a request', () async {
      final adapter = _StubAdapter({'resultcode': 1});
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      final repository = GpsTrackingSyncRepositoryImpl(
        GpsTrackingApiService(dio),
        _context(const SessionUser(id: '4098')),
      );

      final result = await repository.upload(incidentId: 0, records: const []);

      expect(result, isA<Success<bool>>());
      expect(adapter.requests, isEmpty);
    });

    test('the payload serializer omits local-only fields', () {
      final payload = GpsTrackingSyncRequestData(
        incidentId: 0,
        points: [GpsTrackingPointPayload.fromRecord(_record('A', offline: true))],
      );

      expect(payload.toJson().keys, containsAll(['IncidentId', 'data']));
      final point = (payload.toJson()['data'] as List).single as Map;
      expect(
        point.keys.toSet(),
        {'LocationDateTime', 'TaskLatitude', 'TaskLongitude', 'isoffline'},
      );
    });
  });
}
