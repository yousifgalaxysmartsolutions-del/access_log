import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/connectivity_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_capture_sync_bridge.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_location_record.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_pending_store.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_sync_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/repositories/gps_tracking_sync_repository.dart';

class _FakeService implements BackgroundLocationService {
  final _events = StreamController<GpsTrackingEvent>.broadcast();
  void emit(GpsTrackingEvent event) => _events.add(event);

  @override
  Stream<GpsTrackingEvent> get events => _events.stream;

  @override
  Future<void> applyConfiguration(GpsTrackingConfiguration configuration) async {}
  @override
  Future<void> startTracking() async {}
  @override
  Future<void> stopTracking() async {}
  @override
  Future<bool> isTracking() async => false;
  @override
  Future<LocationPermissionStatus> getPermissionStatus() async =>
      LocationPermissionStatus.always;
  @override
  Future<LocationPermissionStatus> requestPermissions() async =>
      LocationPermissionStatus.always;
  @override
  Future<void> openLocationSettings() async {}

  Future<void> dispose() => _events.close();
}

class _FakeStore implements GpsPendingStore {
  _FakeStore(this._records);
  final List<GpsLocationRecord> _records;

  @override
  Future<List<GpsLocationRecord>> readAll() async => List.of(_records);
  @override
  Future<int> count() async => _records.length;
  @override
  Future<int> removeByIds(Set<String> localIds) async {
    final before = _records.length;
    _records.removeWhere((record) => localIds.contains(record.localId));
    return before - _records.length;
  }
}

class _FakeRepository implements GpsTrackingSyncRepository {
  int calls = 0;
  @override
  Future<Result<bool>> upload({
    required int incidentId,
    required List<GpsLocationRecord> records,
  }) async {
    calls++;
    return const Success(true);
  }
}

class _FakeConnectivity implements ConnectivityService {
  @override
  Future<bool> hasInternet() async => true;
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<SessionTokens?> readTokens() async => null;
  @override
  Future<void> writeTokens(SessionTokens tokens) async {}
  @override
  Future<void> clear() async {}
}

GpsLocationRecord _record(String id) => GpsLocationRecord(
  localId: id,
  locationDateTime: DateTime(2025, 9, 9, 12, 38, 49),
  latitude: 30.0972208,
  longitude: 31.2163613,
  isOffline: false,
);

void main() {
  late _FakeService service;
  late _FakeStore store;
  late _FakeRepository repository;
  late GpsTrackingSyncService sync;
  late GpsCaptureSyncBridge bridge;

  setUp(() async {
    service = _FakeService();
    store = _FakeStore([_record('A')]);
    repository = _FakeRepository();
    final session = SessionManager(_MemoryTokenStorage());
    await session.signIn(
      SessionTokens(
        'access',
        'refresh',
        accessTokenExpiresAtUtc: DateTime.utc(2030),
        refreshTokenExpiresAtUtc: DateTime.utc(2030),
      ),
      user: const SessionUser(id: '4098'),
    );
    sync = GpsTrackingSyncService(
      store: store,
      repository: repository,
      connectivity: _FakeConnectivity(),
      session: session,
    );
    bridge = GpsCaptureSyncBridge(service, sync);
  });

  tearDown(() async {
    await bridge.dispose();
    await sync.dispose();
    await service.dispose();
  });

  test('a persisted point triggers an immediate sync attempt', () async {
    bridge.start();

    service.emit(
      const GpsTrackingEvent(type: GpsTrackingEventType.locationCaptured),
    );
    await pumpEventQueue();
    await sync.syncPending();

    expect(repository.calls, 1);
    expect(store._records, isEmpty);
  });

  test('start is idempotent and never double-subscribes', () async {
    bridge.start();
    bridge.start();

    service.emit(
      const GpsTrackingEvent(type: GpsTrackingEventType.locationCaptured),
    );
    await pumpEventQueue();
    await sync.syncPending();

    // A duplicate subscription would have queued a second pass, but the store
    // would already be empty and no second API call would be made.
    expect(repository.calls, 1);
  });

  test('other events do not trigger a sync', () async {
    bridge.start();

    service.emit(
      const GpsTrackingEvent(type: GpsTrackingEventType.trackingStarted),
    );
    await pumpEventQueue();

    expect(repository.calls, 0);
    expect(store._records, hasLength(1));
  });
}
