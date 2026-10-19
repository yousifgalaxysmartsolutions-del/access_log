import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/periodic_photo/data/api/periodic_photo_api_service.dart';
import 'package:access_log_plus/features/periodic_photo/data/models/periodic_photo_payload.dart';
import 'package:access_log_plus/features/periodic_photo/data/repositories/periodic_photo_repository_impl.dart';

import 'support/periodic_photo_fakes.dart';

/// `CAP/CapIncident/SavePeriodicPhoto` contract tests.
///
/// Verifies the exact field names and value shapes at the wire level:
/// `IncidentId` / `ImageData` / `ImageBytes` (never `AnswerBytes`), the real
/// captured extension, raw bytes as a JSON array, the shared CAP envelope, and
/// that only `resultcode == 1` counts as success.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  Map<String, dynamic> body;
  final requests = <RequestOptions>[];
  final requestBodies = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final raw = await utf8.decodeStream(requestStream ?? const Stream.empty());
    requestBodies.add(raw);
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

ApiRequestContextProvider _context(SessionUser? user) =>
    ApiRequestContextProvider(
      users: FixedUserStorage(user),
      deviceInfo: CapDeviceAppInfoProvider(
        osVersion: '15.1',
        deviceType: 'iOS',
        appVersion: '1',
        deviceToken: 'testtokens',
      ),
    );

void main() {
  group('SavePeriodicPhotoRequestData', () {
    test('serializes exactly IncidentId / ImageData / ImageBytes', () {
      const payload = SavePeriodicPhotoRequestData(
        incidentId: 26,
        imageData: 'jpg',
        imageBytes: [1, 2, 3],
      );

      final json = payload.toJson();

      expect(
        json.keys.toList()..sort(),
        ['ImageBytes', 'ImageData', 'IncidentId'],
      );
      expect(json['IncidentId'], 26);
      expect(json['ImageData'], 'jpg');
      expect(json['ImageBytes'], [1, 2, 3]);
      // A different API's field must never be substituted.
      expect(json.containsKey('AnswerBytes'), isFalse);
    });

    test('bytes serialize as a JSON array, never as a Base64 string', () {
      final bytes = jpegEvidence().bytes;
      const payload = SavePeriodicPhotoRequestData(
        incidentId: 0,
        imageData: 'jpg',
        imageBytes: [],
      );
      final encoded = jsonEncode({
        ...payload.toJson(),
        'ImageBytes': bytes.toList(),
      });

      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['ImageBytes'], isA<List<dynamic>>());
      expect(
        (decoded['ImageBytes'] as List).first,
        0xFF,
        reason: 'raw byte values, not a Base64 text',
      );
      expect(decoded['ImageBytes'], hasLength(bytes.length));
    });
  });

  group('PeriodicPhotoRepositoryImpl wire contract', () {
    late _StubAdapter adapter;
    late Dio dio;
    late PeriodicPhotoRepositoryImpl repository;

    void build({SessionUser? user}) {
      adapter = _StubAdapter({
        'resultcode': 1,
        'resultmessages': {'resultmessageen': 'OK'},
      });
      dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      repository = PeriodicPhotoRepositoryImpl(
        PeriodicPhotoApiService(dio),
        _context(user),
      );
    }

    Map<String, dynamic> sentData() {
      final decoded = jsonDecode(adapter.requestBodies.single!)
          as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>;
    }

    test('sends IncidentId, the real extension and raw bytes over the CAP '
        'envelope', () async {
      build(user: const SessionUser(id: '4098'));
      final evidence = jpegEvidence();

      final result = await repository.submit(incidentId: 26, evidence: evidence);

      expect(result, isA<Success<bool>>());
      expect(
        adapter.requests.single.path,
        'CAP/CapIncident/SavePeriodicPhoto',
      );

      // Exact data-block field names from the endpoint contract.
      final data = sentData();
      expect(data.keys.toList()..sort(), [
        'ImageBytes',
        'ImageData',
        'IncidentId',
      ]);
      expect(data['IncidentId'], 26);
      expect(
        data['ImageData'],
        'jpg',
        reason: 'extension detected from the captured bytes',
      );
      expect(data['ImageBytes'], List<int>.of(evidence.bytes));
      expect(data.containsKey('AnswerBytes'), isFalse);

      // Shared envelope: session/device values come from the context, never
      // from hardcoded constants in the feature.
      final envelope = jsonDecode(adapter.requestBodies.single!)
          as Map<String, dynamic>;
      expect(envelope['userid'], 4098);
      expect(envelope['devicetype'], 'iOS');
      expect(envelope['devicetoken'], 'testtokens');
      expect(envelope['osversion'], '15.1');
      expect(envelope['AppVersion'], '1');
      expect(envelope['ipaddress'], isNotEmpty);
    });

    test('a PNG capture uploads ImageData "png", never a hardcoded jpg',
        () async {
      build(user: const SessionUser(id: '4098'));

      final result = await repository.submit(
        incidentId: 0,
        evidence: pngEvidence(),
      );

      expect(result, isA<Success<bool>>());
      final data = sentData();
      expect(data['ImageData'], 'png');
      expect(data['ImageBytes'], List<int>.of(pngEvidence().bytes));
    });

    test('IncidentId 0 outside an incident is sent verbatim', () async {
      build(user: const SessionUser(id: '4098'));

      await repository.submit(incidentId: 0, evidence: jpegEvidence());

      expect(sentData()['IncidentId'], 0);
    });

    test('HTTP 200 with resultcode != 1 is a failure, never a success',
        () async {
      adapter = _StubAdapter({
        'resultcode': 0,
        'resultmessages': {'resultmessageen': 'Invalid payload'},
      });
      dio = Dio(BaseOptions(baseUrl: 'https://cap.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      repository = PeriodicPhotoRepositoryImpl(
        PeriodicPhotoApiService(dio),
        _context(const SessionUser(id: '4098')),
      );

      final result = await repository.submit(
        incidentId: 26,
        evidence: jpegEvidence(),
      );

      expect(result, isA<FailureResult<bool>>());
      final failure = (result as FailureResult<bool>).failure;
      expect(failure, isA<ServiceFailure>());
      expect((failure as ServiceFailure).code, 'cap_result_0');
      expect(failure.message, 'Invalid payload');
    });

    test('a missing session fails before any request is sent', () async {
      build(user: null);

      final result = await repository.submit(
        incidentId: 0,
        evidence: jpegEvidence(),
      );

      expect(result, isA<FailureResult<bool>>());
      expect(
        (result as FailureResult<bool>).failure,
        isA<UnauthorizedFailure>(),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}
