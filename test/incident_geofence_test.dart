import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';
import 'package:access_log_plus/features/incidents/data/repositories/system_gps_configuration_repository_impl.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/system_gps_configuration_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/incident_geofence_use_case.dart';

class _Configuration implements SystemGpsConfigurationRepository {
  Result<SystemGpsConfiguration> result = const Success(
    SystemGpsConfiguration(radiusMeters: 100, enableGpsValidation: true),
  );
  int calls = 0;
  @override
  Future<Result<SystemGpsConfiguration>> load() async {
    calls++;
    return result;
  }
}

class _Transport implements HttpClientAdapter {
  Object? data = {
    'gps': {'gpsRadiusMeters': 100, 'enableGpsValidation': true},
  };
  int code = 1;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({'resultcode': code, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Distance check: inside, outside, and inclusive boundary', () async {
    final repository = _Configuration();
    final gate = IncidentGeofenceUseCase(repository);
    expect(
      await gate(
        '30.0441,31.2354',
        siteLatitude: 30.0444,
        siteLongitude: 31.2357,
      ),
      isA<Success<void>>(),
    );
    final outside = await gate(
      '30.0474,31.2357',
      siteLatitude: 30.0444,
      siteLongitude: 31.2357,
    );
    expect(outside, isA<FailureResult<void>>());
    expect((outside as FailureResult).failure.message, contains('100'));
    final distance = IncidentGeofenceUseCase.distanceMeters(
      30.0441,
      31.2354,
      30.0444,
      31.2357,
    );
    repository.result = Success(
      SystemGpsConfiguration(radiusMeters: distance, enableGpsValidation: true),
    );
    expect(
      await gate(
        '30.0441,31.2354',
        siteLatitude: 30.0444,
        siteLongitude: 31.2357,
      ),
      isA<Success<void>>(),
    );
  });
  test(
    'Missing site, malformed GPS, invalid ranges do not bypass validation',
    () async {
      final repository = _Configuration();
      final gate = IncidentGeofenceUseCase(repository);
      for (final location in ['', 'NaN,31', '91,31', '30,181', '30']) {
        expect(
          await gate(location, siteLatitude: 30, siteLongitude: 31),
          isA<FailureResult<void>>(),
        );
      }
      expect(
        await gate('30,31', siteLatitude: null, siteLongitude: 31),
        isA<FailureResult<void>>(),
      );
      expect(repository.calls, 0);
    },
  );
  test('System configuration failure blocks gate', () async {
    final repository = _Configuration()
      ..result = const FailureResult(ServerFailure());
    expect(
      await IncidentGeofenceUseCase(repository)(
        '30,31',
        siteLatitude: 30,
        siteLongitude: 31,
      ),
      isA<FailureResult<void>>(),
    );
  });
  test('No default radius for invalid configuration', () {
    for (final radius in [0, -1, double.infinity]) {
      expect(
        () => SystemGpsConfiguration.fromJson({
          'gps': {'gpsRadiusMeters': radius, 'enableGpsValidation': true},
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'System API uses authenticated envelope with explicit data:null and fails closed',
    () async {
      final transport = _Transport();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
        ..httpClientAdapter = transport;
      addTearDown(dio.close);
      final repository = SystemGpsConfigurationRepositoryImpl(
        IncidentApiService(dio),
        ApiRequestContextProvider(
          users: null,
          currentUser: () => const SessionUser(id: '4098', name: 'Engineer'),
          deviceInfo: CapDeviceAppInfoProvider(
            appVersion: '1',
            deviceType: 'iOS',
            osVersion: '15.1',
          ),
        ),
      );
      final result = await repository.load();
      expect(result, isA<Success<SystemGpsConfiguration>>());
      expect(
        (result as Success<SystemGpsConfiguration>).data.radiusMeters,
        100,
      );
      expect(
        transport.last!.path,
        'CAP/CapConfiguration/GetSystemConfiguration',
      );
      final json = transport.last!.data as Map;
      expect(json['userid'], 4098);
      expect(json.containsKey('data'), true);
      expect(json['data'], isNull);
      transport.data = null;
      expect(
        await repository.load(),
        isA<FailureResult<SystemGpsConfiguration>>(),
      );
      transport.code = 0;
      expect(
        await repository.load(),
        isA<FailureResult<SystemGpsConfiguration>>(),
      );
    },
  );
}
