import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/connectivity_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_location_record.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_pending_store.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_sync_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/repositories/gps_tracking_sync_repository.dart';

/// In-memory [GpsPendingStore] so the sync policy can be tested without a file.
class _FakeStore implements GpsPendingStore {
  _FakeStore(List<GpsLocationRecord> initial) : _records = [...initial];

  final List<GpsLocationRecord> _records;

  void append(GpsLocationRecord record) => _records.add(record);

  List<GpsLocationRecord> get records => List.unmodifiable(_records);

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
  final List<List<GpsLocationRecord>> uploads = [];
  final List<int> incidentIds = [];
  final Set<int> failCalls = {};
  int calls = 0;

  /// Optional side effect executed at the start of a call, used to simulate the
  /// native tracker capturing a point while the request is in flight.
  void Function(int call)? onUpload;

  /// Optional gate to keep an upload in flight while other calls are made.
  Completer<void>? gate;

  @override
  Future<Result<bool>> upload({
    required int incidentId,
    required List<GpsLocationRecord> records,
  }) async {
    calls++;
    uploads.add(List.of(records));
    incidentIds.add(incidentId);
    onUpload?.call(calls);
    final pendingGate = gate;
    if (pendingGate != null) await pendingGate.future;
    if (failCalls.contains(calls)) {
      return const FailureResult(NetworkFailure());
    }
    return const Success(true);
  }
}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.online = true});
  bool online;

  @override
  Future<bool> hasInternet() async => online;
}

class _MemoryTokenStorage implements TokenStorage {
  SessionTokens? _tokens;

  @override
  Future<SessionTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens(SessionTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

GpsLocationRecord _record(
  String id, {
  bool offline = false,
  int incidentId = 0,
  double latitude = 30.0972208,
  double longitude = 31.2163613,
}) => GpsLocationRecord(
  localId: id,
  locationDateTime: DateTime(2025, 9, 9, 12, 38, 49, 512, 127),
  latitude: latitude,
  longitude: longitude,
  isOffline: offline,
  incidentId: incidentId,
);

Future<SessionManager> _signedInSession() async {
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
  return session;
}

void main() {
  group('GpsTrackingSyncService', () {
    test('offline keeps records and never calls the API', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(online: false),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(repository.calls, 0);
      expect(store.records.map((r) => r.localId), ['A', 'B', 'C']);
      expect(service.status, GpsSyncStatus.offline);
    });

    test('success removes exactly the uploaded records', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(repository.calls, 1);
      expect(repository.uploads.single.map((r) => r.localId), [
        'A',
        'B',
        'C',
      ]);
      expect(store.records, isEmpty);
      expect(service.status, GpsSyncStatus.synced);
      expect(service.lastUploaded, 3);
    });

    test('API failure removes nothing', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository()..failCalls.add(1);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(repository.calls, 1);
      expect(store.records.map((r) => r.localId), ['A', 'B', 'C']);
      expect(service.status, GpsSyncStatus.failed);
    });

    test('CAP failure response removes nothing', () async {
      // The repository already converts `resultcode != 1` into a failure; the
      // service must treat any failure as "keep the whole batch".
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository()..failCalls.add(1);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(store.records, hasLength(3));
      expect(service.status, GpsSyncStatus.failed);
    });

    test('partial queue: a successful batch leaves later records', () async {
      final store = _FakeStore([
        _record('A'),
        _record('B'),
        _record('C'),
        _record('D'),
        _record('E'),
      ]);
      // Second batch fails, so D/E stay behind after A/B/C are deleted.
      final repository = _FakeRepository()..failCalls.add(2);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
        batchSize: 3,
      );

      await service.syncPending();

      expect(repository.uploads.first.map((r) => r.localId), ['A', 'B', 'C']);
      expect(repository.uploads[1].map((r) => r.localId), ['D', 'E']);
      expect(store.records.map((r) => r.localId), ['D', 'E']);
      expect(service.status, GpsSyncStatus.failed);
    });

    test('sends every batch until the backlog is drained', () async {
      final store = _FakeStore([
        _record('A'),
        _record('B'),
        _record('C'),
        _record('D'),
        _record('E'),
      ]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
        batchSize: 2,
      );

      await service.syncPending();

      expect(repository.calls, 3);
      expect(store.records, isEmpty);
      expect(service.lastUploaded, 5);
    });

    test('records captured during a sync are preserved', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository();
      // The native tracker keeps capturing while the request is in flight.
      repository.onUpload = (call) {
        if (call == 1) {
          store.append(_record('D'));
          store.append(_record('E'));
        }
      };
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      // A/B/C were uploaded and deleted; D/E were never part of this run.
      expect(repository.uploads.single.map((r) => r.localId), [
        'A',
        'B',
        'C',
      ]);
      expect(store.records.map((r) => r.localId), ['D', 'E']);
    });

    test('isoffline is preserved from capture time', () async {
      final store = _FakeStore([_record('A', offline: true)]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        // Device is online during sync...
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      // ...but the captured value must not be recomputed.
      expect(repository.uploads.single.single.isOffline, isTrue);
    });

    test('IncidentId is forwarded from the stored records', () async {
      final store = _FakeStore([_record('A', incidentId: 0)]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(repository.incidentIds.single, 0);
    });

    test('duplicate sync calls run only one sync operation', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository()..gate = Completer<void>();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      final first = service.syncPending();
      final second = service.syncPending();
      final third = service.syncPending();

      // Let the single run reach the (blocked) upload.
      await pumpEventQueue();

      // While the single run is blocked on the gate, no extra call happened.
      expect(repository.calls, 1);

      repository.gate!.complete();
      await Future.wait([first, second, third]);

      expect(repository.calls, 1);
      expect(store.records, isEmpty);
    });

    test('unauthenticated keeps records and never calls the API', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        // No sign-in: signed-out session.
        session: SessionManager(_MemoryTokenStorage()),
      );

      await service.syncPending();

      expect(repository.calls, 0);
      expect(store.records.map((r) => r.localId), ['A', 'B', 'C']);
      expect(service.status, GpsSyncStatus.unauthenticated);
    });

    test('pendingCount reflects the store', () async {
      final store = _FakeStore([_record('A'), _record('B')]);
      final service = GpsTrackingSyncService(
        store: store,
        repository: _FakeRepository(),
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      expect(await service.pendingCount(), 2);
    });
  });

  group('GpsTrackingSyncService near-real-time triggers', () {
    test('a new point triggers an immediate sync attempt', () async {
      final store = _FakeStore([_record('A')]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      // Simulates the native `locationCaptured` bridge forwarding a point.
      service.requestSync();
      await service.syncPending();

      expect(repository.calls, 1);
      expect(store.records, isEmpty);
    });

    test('a backlog plus a new point drains in one pass', () async {
      final store = _FakeStore([_record('A'), _record('B')]);
      final repository = _FakeRepository();
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      store.append(_record('C'));
      service.requestSync();
      await service.syncPending();

      expect(repository.uploads.single.map((r) => r.localId), [
        'A',
        'B',
        'C',
      ]);
      expect(store.records, isEmpty);
    });

    test('points captured during a sync go out on the next pass', () async {
      final store = _FakeStore([_record('A'), _record('B'), _record('C')]);
      final repository = _FakeRepository();
      late final GpsTrackingSyncService service;
      repository.onUpload = (call) {
        if (call == 1) {
          store.append(_record('D'));
          store.append(_record('E'));
          // The native capture path re-triggers sync for the new point.
          service.requestSync();
        }
      };
      service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();

      expect(repository.calls, 2);
      expect(repository.uploads[0].map((r) => r.localId), ['A', 'B', 'C']);
      expect(repository.uploads[1].map((r) => r.localId), ['D', 'E']);
      expect(store.records, isEmpty);
    });

    test('a failure then a later point sends the older record too', () async {
      final store = _FakeStore([_record('A')]);
      final repository = _FakeRepository()..failCalls.add(1);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
      );

      await service.syncPending();
      expect(store.records.map((r) => r.localId), ['A']);

      store.append(_record('B'));
      service.requestSync();
      await service.syncPending();

      expect(repository.uploads.last.map((r) => r.localId), ['A', 'B']);
      expect(store.records, isEmpty);
    });

    test('a failed run schedules a backoff retry, not a tight loop', () async {
      final store = _FakeStore([_record('A')]);
      final repository = _FakeRepository()..failCalls.add(1);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
        sweepInterval: const Duration(hours: 1),
        retryDelays: const [Duration(milliseconds: 40)],
      );
      addTearDown(service.stopAutoSync);

      service.startAutoSync();
      await pumpEventQueue();
      expect(repository.calls, 1);
      expect(store.records, hasLength(1));

      // No immediate retry.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repository.calls, 1);

      // The scheduled retry fires and succeeds.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repository.calls, 2);
      expect(store.records, isEmpty);
    });

    test('a successful run resets the backoff', () async {
      final store = _FakeStore([_record('A')]);
      final repository = _FakeRepository()..failCalls.addAll([1, 2]);
      final service = GpsTrackingSyncService(
        store: store,
        repository: repository,
        connectivity: _FakeConnectivity(),
        session: await _signedInSession(),
        sweepInterval: const Duration(hours: 1),
        retryDelays: const [
          Duration(milliseconds: 20),
          Duration(milliseconds: 1000),
        ],
      );
      addTearDown(service.stopAutoSync);

      service.startAutoSync();
      // call1 fails (20ms) → call2 fails (1000ms) → call3 succeeds and resets.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(repository.calls, 3);
      expect(store.records, isEmpty);

      // A later failure must restart from the *first* delay (20ms), proving the
      // backoff was reset rather than capped.
      store.append(_record('B'));
      repository.failCalls.add(4);
      service.requestSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repository.calls, 5);
      expect(store.records, isEmpty);
    });
  });
}
