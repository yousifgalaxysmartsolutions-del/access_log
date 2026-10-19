import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/context/active_incident_context.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/periodic_photo/data/periodic_photo_retain_store.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_coordinator.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_gate.dart';

import 'support/periodic_photo_fakes.dart';

/// Requirement lifecycle: due → capture → CAP accepted → next deadline.
///
/// A failed upload must never cost the user a second photo, and the IncidentId
/// must always come from the live incident context (0 everywhere else).
void main() {
  late FakeSystemConfigurationRepository configuration;
  late MemoryScheduleStore scheduleStore;
  late MemoryRetainStore retainStore;
  late FakePeriodicPhotoRepository repository;
  late ActiveIncidentContext incident;
  late SessionManager session;
  late DateTime now;
  late List<Object?> captureQueue;
  late int captureCalls;
  late PeriodicPhotoCoordinator coordinator;
  late PeriodicPhotoGate gate;

  PeriodicPhotoGate buildGate({
    required PeriodicPhotoCoordinator forCoordinator,
    required SessionManager forSession,
  }) => PeriodicPhotoGate(
    coordinator: forCoordinator,
    repository: repository,
    retainStore: retainStore,
    activeIncident: incident,
    session: forSession,
    capturePhoto: () async {
      captureCalls++;
      if (captureQueue.isEmpty) return null;
      final next = captureQueue.removeAt(0);
      if (next is Exception) throw next;
      return next as CapFormEvidence?;
    },
    now: () => now,
  );

  Future<void> becomeDue() async {
    await gate.reconcile();
    now = DateTime(2026, 1, 1, 10, 1, 0);
    await gate.reconcile();
  }

  setUp(() {
    configuration = FakeSystemConfigurationRepository(
      initial: photoConfiguration(photoEnabled: true, photoInterval: 1),
    );
    scheduleStore = MemoryScheduleStore();
    retainStore = MemoryRetainStore();
    repository = FakePeriodicPhotoRepository();
    incident = ActiveIncidentContext();
    session = SessionManager(MemoryTokenStorage())..startDemo();
    now = DateTime(2026, 1, 1, 10, 0, 0);
    captureQueue = <Object?>[];
    captureCalls = 0;
    coordinator = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: scheduleStore,
      now: () => now,
    );
    gate = buildGate(forCoordinator: coordinator, forSession: session);
  });

  tearDown(() async {
    await gate.dispose();
    await coordinator.dispose();
    await incident.dispose();
    await session.dispose();
  });

  test('enablePhotoCapture = false → no requirement, camera never opens',
      () async {
    configuration.result = Success(photoConfiguration());

    await gate.reconcile();

    expect(gate.state, PeriodicPhotoGateState.disabledByConfiguration);
    expect(gate.state.allowsUsage, isTrue);

    await gate.captureAndSubmit();

    expect(captureCalls, 0);
    expect(repository.submissions, 0);
  });

  test('due photo → capture → CAP accepts → next deadline scheduled',
      () async {
    await becomeDue();
    expect(gate.state, PeriodicPhotoGateState.due);
    expect(gate.state.allowsUsage, isFalse);

    captureQueue.add(jpegEvidence());
    await gate.captureAndSubmit();

    expect(gate.state, PeriodicPhotoGateState.waiting);
    expect(repository.submissions, 1);
    expect(repository.submitted.single.incidentId, 0);
    expect(repository.submitted.single.extension, 'jpg');
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 2, 0),
      reason: 'next due = completion (10:01) + configured interval',
    );
    expect(retainStore.value, isNull, reason: 'nothing left to retry');
  });

  test('cancelling the camera keeps the requirement — it cannot be dismissed',
      () async {
    await becomeDue();

    await gate.captureAndSubmit(); // user cancelled: nothing queued

    expect(captureCalls, 1);
    expect(gate.state, PeriodicPhotoGateState.due);
    expect(repository.submissions, 0);

    // Reconciles can never talk the requirement away either.
    await gate.reconcile();
    await gate.reconcile();
    expect(gate.state, PeriodicPhotoGateState.due);
  });

  test('capture validation failure keeps the requirement and explains why',
      () async {
    await becomeDue();
    captureQueue.add(const FormatException('Evidence exceeds 16 MB'));

    await gate.captureAndSubmit();

    expect(gate.state, PeriodicPhotoGateState.due);
    expect(gate.lastError, contains('16 MB'));
    expect(repository.submissions, 0);
  });

  test('upload failure retains the photo; retry never forces a second capture',
      () async {
    repository.result = networkFailure();
    await becomeDue();
    captureQueue.add(jpegEvidence());

    await gate.captureAndSubmit();

    expect(gate.state, PeriodicPhotoGateState.submitFailed);
    expect(gate.state.allowsUsage, isFalse);
    expect(gate.lastError, isNotNull);
    expect(captureCalls, 1);
    expect(retainStore.value, isNotNull, reason: 'captured before the network');
    expect(
      coordinator.snapshot.state,
      PeriodicPhotoScheduleState.due,
      reason: 'a failed upload must not advance the deadline',
    );
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 1, 0),
    );

    repository.result = const Success(true);
    await gate.retryUpload();

    expect(gate.state, PeriodicPhotoGateState.waiting);
    expect(captureCalls, 1, reason: 'the SAME captured photo is retried');
    expect(repository.submissions, 2);
    expect(repository.submitted.last.name, 'photo.jpg');
    expect(retainStore.value, isNull);
    expect(gate.lastError, isNull);
    expect(
      coordinator.snapshot.nextPhotoDueAt,
      DateTime(2026, 1, 1, 10, 2, 0),
      reason: 'the next window starts only after CAP confirms',
    );
  });

  test('retained photo survives a restart and auto-retries for the same user',
      () async {
    repository.result = networkFailure();
    await becomeDue();
    captureQueue.add(jpegEvidence());
    await gate.captureAndSubmit();
    expect(gate.state, PeriodicPhotoGateState.submitFailed);
    await gate.dispose();
    await coordinator.dispose();

    // "Relaunch": fresh coordinator + gate over the same local state.
    final relaunchedCoordinator = PeriodicPhotoCoordinator(
      configuration: configuration,
      store: scheduleStore,
      now: () => now,
    );
    addTearDown(relaunchedCoordinator.dispose);
    final relaunchedGate = buildGate(
      forCoordinator: relaunchedCoordinator,
      forSession: session,
    );
    addTearDown(relaunchedGate.dispose);
    repository.result = const Success(true);
    final capturesBefore = captureCalls;

    await relaunchedGate.reconcile();

    expect(relaunchedGate.state, PeriodicPhotoGateState.waiting);
    expect(captureCalls, capturesBefore, reason: 'no second photo was needed');
    expect(repository.submissions, 2);
    expect(retainStore.value, isNull);
  });

  test('retained photo is never restored for a different user', () async {
    retainStore.value = RetainedPeriodicPhoto(
      evidence: jpegEvidence(),
      incidentId: 9,
      capturedAt: now,
      userId: 42,
    );

    await gate.reconcile(); // schedule the window at 10:01
    now = DateTime(2026, 1, 1, 10, 1, 0);
    await gate.reconcile(); // deadline reached

    expect(gate.state, PeriodicPhotoGateState.due);
    expect(gate.retainedPhoto, isNull);
    expect(retainStore.value, isNull, reason: 'discarded, not uploaded');
    expect(repository.submissions, 0);
  });

  test('signed-out session never restores or uploads a retained photo',
      () async {
    final signedOut = SessionManager(MemoryTokenStorage());
    addTearDown(signedOut.dispose);
    retainStore.value = RetainedPeriodicPhoto(
      evidence: jpegEvidence(),
      incidentId: 0,
      capturedAt: now,
      userId: 0,
    );
    final signedOutGate = buildGate(
      forCoordinator: coordinator,
      forSession: signedOut,
    );
    addTearDown(signedOutGate.dispose);

    await signedOutGate.reconcile(); // schedule the window at 10:01
    now = DateTime(2026, 1, 1, 10, 1, 0);
    await signedOutGate.reconcile(); // deadline reached

    expect(signedOutGate.state, PeriodicPhotoGateState.due);
    expect(repository.submissions, 0);
    expect(retainStore.value, isNull);
  });

  test('IncidentId comes from the live incident context, 0 elsewhere',
      () async {
    await becomeDue();

    incident.enter(26);
    captureQueue.add(jpegEvidence());
    await gate.captureAndSubmit();

    expect(repository.submitted.single.incidentId, 26);

    // Leaving the incident before the next window: the stale id must not leak.
    incident.leave(26);
    now = DateTime(2026, 1, 1, 10, 2, 0);
    await gate.reconcile();
    captureQueue.add(pngEvidence());
    await gate.captureAndSubmit();

    expect(repository.submitted.last.incidentId, 0);
    expect(
      repository.submitted.last.extension,
      'png',
      reason: 'the real captured format is sent, never a hardcoded jpg',
    );
  });

  test('configuration disabled while a photo is outstanding → released',
      () async {
    await becomeDue();
    expect(gate.state, PeriodicPhotoGateState.due);

    configuration.result = Success(photoConfiguration());
    await gate.reconcile();

    expect(gate.state, PeriodicPhotoGateState.disabledByConfiguration);
    expect(gate.state.allowsUsage, isTrue);
  });

  test('retake discards the retained photo and captures a fresh one',
      () async {
    repository.result = networkFailure();
    await becomeDue();
    captureQueue.add(jpegEvidence(name: 'first.jpg'));
    await gate.captureAndSubmit();
    expect(gate.state, PeriodicPhotoGateState.submitFailed);

    repository.result = const Success(true);
    captureQueue.add(pngEvidence(name: 'second.png'));
    await gate.retake();

    expect(captureCalls, 2);
    expect(repository.submitted.last.name, 'second.png');
    expect(repository.submitted.last.extension, 'png');
    expect(gate.state, PeriodicPhotoGateState.waiting);
  });

  test('duplicate reconcile while due → exactly one gate state emission',
      () async {
    await gate.reconcile();
    final states = <PeriodicPhotoGateState>[];
    final subscription = gate.changes.listen(states.add);

    now = DateTime(2026, 1, 1, 10, 1, 0);
    await gate.reconcile();
    await gate.reconcile();
    await gate.reconcile();

    expect(states, [PeriodicPhotoGateState.due]);
    expect(gate.state, PeriodicPhotoGateState.due);
    await subscription.cancel();
  });
}
