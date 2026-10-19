import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_requirement_gate.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_manager.dart';
import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/system_gps_configuration_repository.dart';

/// Native tracking double: records calls and lets a test drive permission,
/// location-services and tracker state.
class _FakeService implements BackgroundLocationService {
  final List<GpsTrackingConfiguration> applied = [];
  int startCalls = 0;
  int stopCalls = 0;
  int permissionRequests = 0;
  int openSettingsCalls = 0;
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
  int loads = 0;
  Result<SystemGpsConfiguration> result = Success(_configuration(true));

  @override
  Future<Result<SystemGpsConfiguration>> load() async {
    loads++;
    return result;
  }
}

SystemGpsConfiguration _configuration(bool continuous) => SystemGpsConfiguration(
  radiusMeters: 100,
  enableGpsValidation: true,
  continuousGpsTracking: continuous,
  periodicGpsCaptureIntervalMinutes: 1,
);

void main() {
  late _FakeService service;
  late _FakeConfiguration configuration;
  late GpsTrackingManager manager;
  late GpsRequirementGate gate;

  setUp(() {
    service = _FakeService();
    configuration = _FakeConfiguration();
    manager = GpsTrackingManager(service, configuration);
    gate = GpsRequirementGate(manager);
  });

  tearDown(() async {
    await gate.dispose();
    await manager.dispose();
    await service.dispose();
  });

  test('config false → app allowed, gate disabled by configuration', () async {
    configuration.result = Success(_configuration(false));

    await gate.reconcile();

    expect(gate.state, GpsGateState.disabledByConfiguration);
    expect(gate.state.allowsUsage, isTrue);
  });

  test('config true + everything ready → app allowed', () async {
    await gate.reconcile();

    expect(gate.state, GpsGateState.ready);
    expect(gate.state.allowsUsage, isTrue);
    expect(service.startCalls, 1);
  });

  test('config true + location services off → blocked', () async {
    service.permission = LocationPermissionStatus.serviceDisabled;

    await gate.reconcile();

    expect(gate.state, GpsGateState.locationServicesDisabled);
    expect(gate.state.allowsUsage, isFalse);
    expect(service.startCalls, 0);
  });

  test('config true + foreground permission missing → blocked', () async {
    service.permission = LocationPermissionStatus.notDetermined;

    await gate.reconcile();

    expect(gate.state, GpsGateState.permissionRequired);
    expect(gate.state.allowsUsage, isFalse);
  });

  test('config true + permission denied → blocked', () async {
    service.permission = LocationPermissionStatus.denied;

    await gate.reconcile();

    expect(gate.state, GpsGateState.permissionRequired);
  });

  test('config true + background permission missing → blocked', () async {
    service.permission = LocationPermissionStatus.whenInUse;

    await gate.reconcile();

    expect(gate.state, GpsGateState.backgroundPermissionRequired);
    expect(gate.state.allowsUsage, isFalse);
  });

  test('config true + tracker stopped → start attempted, then ready', () async {
    service.tracking = false;

    await gate.reconcile();

    expect(service.startCalls, 1);
    expect(gate.state, GpsGateState.ready);
  });

  test('configuration load failure → error (blocking)', () async {
    configuration.result = const FailureResult(NetworkFailure());

    await gate.reconcile();

    expect(gate.state, GpsGateState.error);
    expect(gate.state.allowsUsage, isFalse);
  });

  test('GPS off while ready → blocking, and back on → ready again', () async {
    await gate.reconcile();
    expect(gate.state, GpsGateState.ready);

    service.permission = LocationPermissionStatus.serviceDisabled;
    service.emit(
      const GpsTrackingEvent(type: GpsTrackingEventType.locationServicesDisabled),
    );
    await pumpEventQueue();
    expect(gate.state, GpsGateState.locationServicesDisabled);
    expect(gate.state.allowsUsage, isFalse);

    // User re-enables Location Services: the native permissionChanged event
    // triggers a config-free reconcile and the tracker resumes.
    service.permission = LocationPermissionStatus.always;
    service.tracking = false;
    service.emit(
      const GpsTrackingEvent(
        type: GpsTrackingEventType.permissionChanged,
        permission: LocationPermissionStatus.always,
      ),
    );
    await pumpEventQueue();
    expect(gate.state, GpsGateState.ready);
    expect(service.startCalls, 2);
  });

  test('permission revoked → blocked, restored → ready automatically', () async {
    await gate.reconcile();
    expect(gate.state, GpsGateState.ready);

    service.permission = LocationPermissionStatus.whenInUse;
    service.emit(
      const GpsTrackingEvent(
        type: GpsTrackingEventType.permissionChanged,
        permission: LocationPermissionStatus.whenInUse,
      ),
    );
    await pumpEventQueue();
    expect(gate.state, GpsGateState.backgroundPermissionRequired);

    service.permission = LocationPermissionStatus.always;
    service.emit(
      const GpsTrackingEvent(
        type: GpsTrackingEventType.permissionChanged,
        permission: LocationPermissionStatus.always,
      ),
    );
    await pumpEventQueue();
    expect(gate.state, GpsGateState.ready);
  });

  test('tracker stopped unexpectedly → restarted automatically', () async {
    await gate.reconcile();
    expect(service.startCalls, 1);

    service.tracking = false;
    service.emit(
      const GpsTrackingEvent(type: GpsTrackingEventType.trackingStopped),
    );
    await pumpEventQueue();

    expect(service.startCalls, 2);
    expect(gate.state, GpsGateState.ready);
  });

  test('warm resume reconcile refreshes configuration', () async {
    await gate.reconcile();
    final loadsAfterStart = configuration.loads;

    // Simulates AppLifecycleState.resumed calling the gate again.
    await gate.reconcile();

    expect(configuration.loads, loadsAfterStart + 1);
    expect(gate.state, GpsGateState.ready);
  });

  test('repeated reconcile does not create a second tracker', () async {
    await gate.reconcile();
    await gate.reconcile();
    await gate.reconcile();

    expect(service.startCalls, 1);
    expect(gate.state, GpsGateState.ready);
  });

  test('requestPermissions then reconcile clears the permission gate', () async {
    service.permission = LocationPermissionStatus.notDetermined;
    service.requestResult = LocationPermissionStatus.always;
    await gate.reconcile();
    expect(gate.state, GpsGateState.permissionRequired);

    await gate.requestPermissions();

    expect(service.permissionRequests, 1);
    expect(gate.state, GpsGateState.ready);
  });

  test('openLocationSettings forwards to the native side', () async {
    await gate.openLocationSettings();
    expect(service.openSettingsCalls, 1);
  });
}
