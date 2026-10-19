import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_manager.dart';
import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/system_gps_configuration_repository.dart';

/// In-memory [BackgroundLocationService] that records every call, so the
/// manager's policy can be verified without any platform channel or native code.
class _FakeService implements BackgroundLocationService {
  final List<GpsTrackingConfiguration> applied = [];
  int startCalls = 0;
  int stopCalls = 0;
  int permissionRequests = 0;
  bool tracking = false;

  LocationPermissionStatus permission = LocationPermissionStatus.always;
  LocationPermissionStatus requestResult = LocationPermissionStatus.always;

  final _events = StreamController<GpsTrackingEvent>.broadcast();

  @override
  Future<void> applyConfiguration(GpsTrackingConfiguration configuration) async {
    applied.add(configuration);
  }

  @override
  Future<void> startTracking() async {
    startCalls++;
    tracking = true;
  }

  @override
  Future<void> stopTracking() async {
    stopCalls++;
    tracking = false;
  }

  @override
  Future<bool> isTracking() async => tracking;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermissions() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  int openSettingsCalls = 0;

  @override
  Future<void> openLocationSettings() async {
    openSettingsCalls++;
  }

  @override
  Stream<GpsTrackingEvent> get events => _events.stream;

  void emit(GpsTrackingEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();
}

class _FakeConfiguration implements SystemGpsConfigurationRepository {
  Result<SystemGpsConfiguration> result = const Success(
    SystemGpsConfiguration(
      radiusMeters: 100,
      enableGpsValidation: true,
      continuousGpsTracking: true,
    ),
  );

  @override
  Future<Result<SystemGpsConfiguration>> load() async => result;
}

SystemGpsConfiguration _configuration({required bool continuous}) =>
    SystemGpsConfiguration(
      radiusMeters: 100,
      enableGpsValidation: true,
      continuousGpsTracking: continuous,
      periodicGpsCaptureIntervalMinutes: 1,
      gpsAccuracyThreshold: 1.0,
      allowOfflineGpsCollection: false,
    );

void main() {
  late _FakeService service;
  late _FakeConfiguration configuration;
  late GpsTrackingManager manager;

  setUp(() {
    service = _FakeService();
    configuration = _FakeConfiguration();
    manager = GpsTrackingManager(service, configuration);
  });

  tearDown(() async {
    await manager.dispose();
    await service.dispose();
  });

  test('continuousGpsTracking false stops the tracker', () async {
    service.tracking = true;
    configuration.result = Success(_configuration(continuous: false));

    await manager.reconcile();

    expect(service.stopCalls, 1);
    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.stopped);
  });

  test('continuousGpsTracking true starts the tracker once', () async {
    configuration.result = Success(_configuration(continuous: true));

    await manager.reconcile();

    expect(service.startCalls, 1);
    expect(service.applied.single.continuousGpsTracking, isTrue);
    expect(manager.status, GpsTrackingStatus.running);
  });

  test('duplicate reconciliation does not create a second tracker', () async {
    configuration.result = Success(_configuration(continuous: true));

    await manager.reconcile();
    await manager.reconcile();
    await manager.reconcile();

    expect(service.startCalls, 1);
    expect(manager.status, GpsTrackingStatus.running);
  });

  test('app restart with an already running tracker does not restart it', () async {
    // Simulates Flutter restarting while the native tracker kept running.
    service.tracking = true;
    configuration.result = Success(_configuration(continuous: true));

    await manager.reconcile();

    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.running);
  });

  test('awaiting permission when only foreground permission is granted', () async {
    service.permission = LocationPermissionStatus.whenInUse;
    configuration.result = Success(_configuration(continuous: true));

    await manager.reconcile();

    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.awaitingPermission);
  });

  test('location services disabled surfaces an error without starting', () async {
    service.permission = LocationPermissionStatus.serviceDisabled;
    configuration.result = Success(_configuration(continuous: true));

    await manager.reconcile();

    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.error);
  });

  test('configuration failure does not tear down a running tracker', () async {
    service.tracking = true;
    configuration.result = const FailureResult(NetworkFailure());

    await manager.reconcile();

    expect(service.stopCalls, 0);
    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.error);
  });

  test('enableTracking requests permission once then starts', () async {
    service.requestResult = LocationPermissionStatus.always;
    configuration.result = Success(_configuration(continuous: true));

    final status = await manager.enableTracking();

    expect(service.permissionRequests, 1);
    expect(service.startCalls, 1);
    expect(status, GpsTrackingStatus.running);
  });

  test('enableTracking stops at awaiting permission when denied', () async {
    service.requestResult = LocationPermissionStatus.denied;
    configuration.result = Success(_configuration(continuous: true));

    final status = await manager.enableTracking();

    expect(service.permissionRequests, 1);
    expect(service.startCalls, 0);
    expect(status, GpsTrackingStatus.awaitingPermission);
  });

  test('stopTracking stops the native tracker', () async {
    configuration.result = Success(_configuration(continuous: true));
    await manager.reconcile();

    await manager.stopTracking();

    expect(service.stopCalls, 1);
    expect(manager.status, GpsTrackingStatus.stopped);
  });

  test('background permission granted later starts tracking automatically', () async {
    // Foreground-only at first: nothing starts.
    service.permission = LocationPermissionStatus.whenInUse;
    configuration.result = Success(_configuration(continuous: true));
    await manager.reconcile();

    expect(service.startCalls, 0);
    expect(manager.status, GpsTrackingStatus.awaitingPermission);

    // The OS upgrades to Always (e.g. the iOS two-step prompt).
    service.permission = LocationPermissionStatus.always;
    service.emit(
      const GpsTrackingEvent(
        type: GpsTrackingEventType.permissionChanged,
        permission: LocationPermissionStatus.always,
      ),
    );
    await pumpEventQueue();

    expect(service.startCalls, 1);
    expect(manager.status, GpsTrackingStatus.running);
  });
}
