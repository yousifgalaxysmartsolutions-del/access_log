import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/context/active_incident_context.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/periodic_photo/data/today_in_process_store.dart';
import 'package:access_log_plus/features/periodic_photo/domain/today_in_process_incident_service.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_coordinator.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_gate.dart';
import 'support/periodic_photo_fakes.dart';

class MemoryIncidentStore extends TodayInProcessStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    value = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

class ActionDetails implements IncidentDetailsRepository {
  ActionDetails(this.result);
  Result<IncidentDetailsData> result;
  int calls = 0;
  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DateTime now;
  late SessionManager session;
  late MemoryIncidentStore store;
  late TodayInProcessIncidentService cache;
  Future<void> enter(int id) => cache.confirmStatus(
    id,
    status: 4,
    number: 'INC-$id',
    generation: session.generation,
  );
  ActionDetails details({int status = 4, int? owner = 4099}) => ActionDetails(
    Success(
      IncidentDetailsData.fromJson({
        'id': 1,
        'incidentNo': 'INC-1',
        'status': {'id': status},
        'assignedEngineer': owner == null ? null : {'id': owner},
      }),
    ),
  );
  setUp(() {
    now = DateTime(2026, 10, 20, 9);
    session = SessionManager(MemoryTokenStorage())..startDemo();
    session.user = const SessionUser(id: '4099', name: 'Engineer');
    store = MemoryIncidentStore();
    cache = TodayInProcessIncidentService(
      session: session,
      store: store,
      now: () => now,
    );
  });
  tearDown(() async {
    await cache.dispose();
    await session.dispose();
  });

  test(
    'only confirmed local transitions enter; repetition preserves latest',
    () async {
      await enter(1);
      now = now.add(const Duration(minutes: 1));
      await enter(2);
      expect(cache.latest!.id, 2);
      await enter(1);
      expect(cache.latest!.id, 2);
      await cache.confirmStatus(2, status: 7, generation: session.generation);
      expect(cache.latest!.id, 1);
      await enter(2);
      expect(cache.latest!.id, 2);
    },
  );

  test('Entry/Un Hold verifies actual status and current assignee', () async {
    final api = details();
    await cache.recordSuccessfulAction(
      incidentId: 1,
      stamp: cache.beginObservation(),
      allowEntry: true,
      details: api,
    );
    expect(cache.latest!.id, 1);
    expect(api.calls, 1);
    await cache.confirmStatus(1, status: 7, generation: session.generation);
    await cache.recordSuccessfulAction(
      incidentId: 1,
      stamp: cache.beginObservation(),
      allowEntry: true,
      details: details(status: 3),
    );
    expect(cache.hasEligibleIncident, false);
    await cache.recordSuccessfulAction(
      incidentId: 1,
      stamp: cache.beginObservation(),
      allowEntry: true,
      details: details(owner: 4100),
    );
    expect(cache.hasEligibleIncident, false);
    await cache.recordSuccessfulAction(
      incidentId: 1,
      stamp: cache.beginObservation(),
      allowEntry: true,
      details: details(owner: null),
    );
    expect(cache.hasEligibleIncident, false);
  });

  test(
    'Renewal does not enroll existing work not started by this user',
    () async {
      final api = details();
      await cache.recordSuccessfulAction(
        incidentId: 1,
        stamp: cache.beginObservation(),
        details: api,
      );
      expect(api.calls, 0);
      expect(cache.hasEligibleIncident, false);
      await enter(1);
      await cache.recordSuccessfulAction(
        incidentId: 1,
        stamp: cache.beginObservation(),
        details: details(status: 5),
      );
      expect(cache.hasEligibleIncident, false);
    },
  );

  test('failed verification never invents a transition', () async {
    await cache.recordSuccessfulAction(
      incidentId: 1,
      stamp: cache.beginObservation(),
      allowEntry: true,
      details: ActionDetails(const FailureResult(NetworkFailure())),
    );
    expect(cache.hasEligibleIncident, false);
    await cache.confirmStatus(1, status: 0, generation: session.generation);
    expect(cache.hasEligibleIncident, false);
  });

  test('stale results cannot resurrect completed work', () async {
    final earlier = cache.beginObservation();
    await cache.confirmStatus(1, status: 5, generation: session.generation);
    await cache.confirmStatus(
      1,
      status: 4,
      generation: session.generation,
      stamp: earlier,
    );
    expect(cache.hasEligibleIncident, false);
  });

  test('user/day persistence and action-only cache migration', () async {
    await enter(1);
    final restored = TodayInProcessIncidentService(
      session: session,
      store: store,
      now: () => now,
    );
    await restored.restore();
    expect(restored.latest!.id, 1);
    await restored.dispose();
    // Old list-based records must not enable photos under the new policy.
    store.value!.remove('sourceVersion');
    final migrated = TodayInProcessIncidentService(
      session: session,
      store: store,
      now: () => now,
    );
    await migrated.restore();
    expect(migrated.hasEligibleIncident, false);
    await migrated.dispose();
    final previousUser = cache.beginObservation();
    await session.logout();
    session.startDemo();
    session.user = const SessionUser(id: '4100');
    await cache.restore();
    await cache.confirmStatus(
      1,
      status: 4,
      generation: previousUser.generation,
      stamp: previousUser,
    );
    expect(cache.hasEligibleIncident, false);
    await enter(2);
    expect(cache.latest!.id, 2);
    final yesterday = cache.beginObservation();
    now = now.add(const Duration(days: 1));
    await cache.confirmStatus(
      3,
      status: 4,
      generation: session.generation,
      stamp: yesterday,
    );
    expect(cache.hasEligibleIncident, false);
  });

  test(
    'equal timestamps use last local transition, not largest incident ID',
    () async {
      await enter(99);
      await enter(1);
      expect(cache.latest!.id, 1);
      final restored = TodayInProcessIncidentService(
        session: session,
        store: store,
        now: () => now,
      );
      await restored.restore();
      await restored.confirmStatus(
        2,
        status: 4,
        generation: session.generation,
      );
      expect(restored.latest!.id, 2);
      await restored.dispose();
    },
  );

  test('durable store writes atomically and tolerates corrupt JSON', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cap_incident_cache_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final disk = TodayInProcessStore(directory: () async => directory);
    expect(await disk.read(), isNull);
    await disk.write({'scope': '4099:today', 'incidents': []});
    expect((await disk.read())!['scope'], '4099:today');
    await File(
      '${directory.path}/cap_photo/in_process_today.json',
    ).writeAsString('{broken');
    expect(await disk.read(), isNull);
  });

  test(
    'photo timer runs only with work; latest incident is used outside details; restart retains deadline',
    () async {
      final configuration = FakeSystemConfigurationRepository(
        initial: photoConfiguration(photoEnabled: true, photoInterval: 2),
      );
      final scheduleStore = MemoryScheduleStore();
      final coordinator = PeriodicPhotoCoordinator(
        configuration: configuration,
        store: scheduleStore,
        now: () => now,
        incidents: cache,
      );
      final repository = FakePeriodicPhotoRepository();
      final context = ActiveIncidentContext()..enter(999);
      var captures = 0;
      final gate = PeriodicPhotoGate(
        coordinator: coordinator,
        repository: repository,
        retainStore: MemoryRetainStore(),
        activeIncident: context,
        session: session,
        incidents: cache,
        now: () => now,
        capturePhoto: () async {
          captures++;
          return CapFormEvidence(
            name: 'selfie.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2]),
          );
        },
      );
      addTearDown(() async {
        await gate.dispose();
        await coordinator.dispose();
        await context.dispose();
      });
      await gate.reconcile();
      now = now.add(const Duration(minutes: 10));
      await gate.reconcile();
      await gate.captureAndSubmit();
      expect(captures, 0);
      await enter(1);
      await coordinator.reconcile();
      final due = coordinator.snapshot.nextPhotoDueAt;
      expect(due, now.add(const Duration(minutes: 2)));
      now = now.add(const Duration(minutes: 1));
      await enter(2);
      await coordinator.reconcile();
      expect(coordinator.snapshot.nextPhotoDueAt, due);
      now = now.add(const Duration(minutes: 1));
      await gate.reconcile();
      await gate.captureAndSubmit();
      expect(captures, 1);
      expect(repository.submitted.single.incidentId, 2);
      final afterUpload = coordinator.snapshot.nextPhotoDueAt;
      await coordinator.reconcile();
      expect(
        coordinator.snapshot.nextPhotoDueAt,
        afterUpload,
        reason: 'successful upload preserves user/day scope',
      );
      now = now.add(const Duration(minutes: 2));
      await gate.reconcile();
      repository.result = const FailureResult(NetworkFailure());
      await gate.captureAndSubmit();
      expect(gate.retainedPhoto, isNotNull);
      await cache.confirmStatus(1, status: 7, generation: session.generation);
      await cache.confirmStatus(2, status: 5, generation: session.generation);
      await coordinator.reconcile();
      expect(coordinator.snapshot.state, PeriodicPhotoScheduleState.disabled);
      expect(gate.retainedPhoto, isNull);
      now = now.add(const Duration(minutes: 10));
      await enter(2);
      await gate.reconcile();
      expect(
        gate.state,
        PeriodicPhotoGateState.waiting,
        reason:
            'an old failed photo must not revive a requirement after a pause',
      );
      expect(
        coordinator.snapshot.nextPhotoDueAt,
        now.add(const Duration(minutes: 2)),
      );
      final restarted = PeriodicPhotoCoordinator(
        configuration: configuration,
        store: scheduleStore,
        now: () => now,
        incidents: cache,
      );
      await restarted.reconcile();
      expect(
        restarted.snapshot.nextPhotoDueAt,
        coordinator.snapshot.nextPhotoDueAt,
      );
      await restarted.dispose();
    },
  );
}
