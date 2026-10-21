import 'dart:async';

import '../../../core/context/active_incident_context.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/result.dart';
import '../../../core/session/session_manager.dart';
import '../../forms/data/models/cap_form_models.dart';
import '../data/periodic_photo_retain_store.dart';
import 'periodic_photo_coordinator.dart';
import 'repositories/periodic_photo_repository.dart';
import 'today_in_process_incident_service.dart';

/// The blocking state of the app-level periodic photo requirement.
///
/// Mirrors [GpsGateState] in shape so the root guard can reason about both
/// requirements the same way, but *only* [due], [submitting] and
/// [submitFailed] block usage: a failed configuration read or an unknown first
/// state must never lock the user out of CAP.
enum PeriodicPhotoGateState {
  /// No configuration has been read yet. Not blocking.
  checking,

  /// `enablePhotoCapture == false` (or no usable interval). Not blocking.
  disabledByConfiguration,

  /// A deadline exists in the future. Not blocking.
  waiting,

  /// The deadline passed: exactly one photo is required. Blocking until CAP
  /// accepts it — there is no dismiss/skip action anywhere in the UI.
  due,

  /// A captured photo is being uploaded. Still blocking: the requirement is
  /// only fulfilled when CAP confirms.
  submitting,

  /// CAP rejected or could not accept the upload. Blocking, but the captured
  /// photo is retained (in memory and on disk) so a retry never forces the
  /// user to take a second photo.
  submitFailed;

  /// Whether normal CAP usage is allowed while in this state.
  bool get allowsUsage => switch (this) {
    PeriodicPhotoGateState.checking ||
    PeriodicPhotoGateState.disabledByConfiguration ||
    PeriodicPhotoGateState.waiting => true,
    PeriodicPhotoGateState.due ||
    PeriodicPhotoGateState.submitting ||
    PeriodicPhotoGateState.submitFailed => false,
  };
}

/// Centralized periodic-photo requirement coordinator.
///
/// ```text
/// GetSystemConfiguration → PeriodicPhotoCoordinator (timing, persisted)
///                                   ↓ due deadline
///                           PeriodicPhotoGate (state + intents)
///                                   ↓ one root overlay
///                           AppRequirementGuard (GPS first, then photo)
///                                   ↓ user intent
///                    PeriodicPhotoCapture UI → PeriodicPhotoRepository
///                                   ↓
///                         CAP/CapIncident/SavePeriodicPhoto
/// ```
///
/// Separation of concerns: the *coordinator* owns configuration/timing policy,
/// the *gate* owns the requirement's lifecycle (capture, upload, retention) and
/// the *guard/screen* own nothing but rendering state and forwarding intents.
/// There is no screen-owned timer and no per-screen logic anywhere.
///
/// Camera capture only ever starts from an explicit user intent
/// ([captureAndSubmit]/[retake]) — never on a deadline, never on resume, never
/// while backgrounded.
class PeriodicPhotoGate {
  PeriodicPhotoGate({
    required PeriodicPhotoCoordinator coordinator,
    required PeriodicPhotoRepository repository,
    required PeriodicPhotoRetainStore retainStore,
    required ActiveIncidentContext activeIncident,
    required SessionManager session,
    required Future<CapFormEvidence?> Function() capturePhoto,
    DateTime Function()? now,
    TodayInProcessIncidentService? incidents,
  }) : _coordinator = coordinator,
       _repository = repository,
       _retainStore = retainStore,
       _activeIncident = activeIncident,
       _session = session,
       _capturePhoto = capturePhoto,
       _now = now ?? DateTime.now {
    _incidents = incidents;
    _incidentSubscription = incidents?.changes.listen((_) => _derive());
    _coordinatorSubscription = _coordinator.changes.listen((_) => _derive());
  }
  TodayInProcessIncidentService? _incidents;
  StreamSubscription<void>? _incidentSubscription;

  final PeriodicPhotoCoordinator _coordinator;
  final PeriodicPhotoRepository _repository;
  final PeriodicPhotoRetainStore _retainStore;
  final ActiveIncidentContext _activeIncident;
  final SessionManager _session;
  final Future<CapFormEvidence?> Function() _capturePhoto;
  final DateTime Function() _now;

  final _changes = StreamController<PeriodicPhotoGateState>.broadcast();
  late final StreamSubscription<PeriodicPhotoSnapshot> _coordinatorSubscription;

  PeriodicPhotoGateState _state = PeriodicPhotoGateState.checking;
  PeriodicPhotoGateState get state => _state;

  /// Requirement-state changes, for the blocking UI to render.
  Stream<PeriodicPhotoGateState> get changes => _changes.stream;

  /// Last upload/capture error message, shown while [PeriodicPhotoGateState
  /// .submitFailed].
  String? get lastError => _lastError;
  String? _lastError;
  String? _emittedError;

  /// The captured photo waiting for a CAP confirmation, if any.
  RetainedPeriodicPhoto? get retainedPhoto => _retainedPhoto;
  RetainedPeriodicPhoto? _retainedPhoto;

  bool _submitting = false;
  bool _busy = false;
  bool _restored = false;
  bool _disposed = false;
  Future<void> _pendingRetentionClear = Future.value();

  Future<void>? _reconciling;
  bool _pendingReconcile = false;

  /// Reconciles the requirement with the system configuration and lifecycle.
  ///
  /// Called on cold start, authenticated session, configuration refresh and
  /// `AppLifecycleState.resumed` — the same triggers as the GPS gate, never on
  /// a short poll. Single-flight: concurrent calls share one run and a call
  /// arriving mid-run requests exactly one follow-up pass.
  ///
  /// Also restores a captured-but-unsubmitted photo (once) and retries its
  /// upload — still the *same* photo, never a new capture.
  Future<void> reconcile() {
    final active = _reconciling;
    if (active != null) {
      _pendingReconcile = true;
      return active;
    }
    final started = _runReconcile();
    _reconciling = started;
    return started.whenComplete(() {
      if (identical(_reconciling, started)) _reconciling = null;
      if (_pendingReconcile) {
        _pendingReconcile = false;
        unawaited(reconcile());
      }
    });
  }

  Future<void> _runReconcile() async {
    await _incidents?.restore();
    await _restoreOnce();
    await _coordinator.reconcile();
    _derive();
    if (_state == PeriodicPhotoGateState.submitFailed &&
        _retainedPhoto != null &&
        _session.isAuthenticated) {
      // Retry the already-captured photo on the way back in (resume/re-login).
      await _submitRetained();
    }
  }

  /// Restores a captured-but-unsubmitted photo from disk, exactly once.
  ///
  /// Retention survives an app restart, but only for the same CAP user: a photo
  /// taken by someone else must never be uploaded under the current identity.
  Future<void> _restoreOnce() async {
    if (_restored) return;
    _restored = true;
    final retained = await _retainStore.read();
    if (retained == null || _retainedPhoto != null) return;
    if (!_session.isAuthenticated || retained.userId != _session.userId) {
      await _discardRetainedPhoto();
      return;
    }
    _retainedPhoto = retained;
    _derive();
  }

  /// User intent: open the camera and submit what is captured.
  ///
  /// Cancelling the camera simply leaves the requirement [due] — it cannot be
  /// dismissed. Exactly one attempt runs at a time.
  Future<void> captureAndSubmit() async {
    if (!_begin()) return;
    final generation = _session.generation;
    try {
      final evidence = await _capture();
      if (evidence == null) return;
      if (_session.generation != generation || !_session.isAuthenticated) {
        return;
      }
      final eligibleId = _incidents?.latest?.id;
      if (_incidents != null && eligibleId == null) {
        _derive();
        return;
      }
      await _submit(
        RetainedPeriodicPhoto(
          evidence: evidence,
          // Production uses the latest eligible incident, never the open route.
          incidentId: eligibleId ?? _activeIncident.uploadIncidentId,
          capturedAt: _now(),
          userId: _session.userId,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// User intent: re-upload the already-captured photo without taking another
  /// one. Falls back to a capture only when nothing is retained (which cannot
  /// happen while [PeriodicPhotoGateState.submitFailed]).
  Future<void> retryUpload() async {
    if (_retainedPhoto == null) {
      await captureAndSubmit();
      return;
    }
    if (!_begin()) return;
    try {
      await _submitRetained();
    } finally {
      _busy = false;
    }
  }

  /// User intent from a failed upload: explicitly discard the retained photo
  /// and take a new one. Never called automatically — a failed upload must not
  /// force a second capture on its own.
  Future<void> retake() async {
    if (_busy || _disposed) return;
    await _discardRetainedPhoto();
    await captureAndSubmit();
  }

  bool _begin() {
    if (_disposed || _busy) return false;
    if (_incidents != null && !_incidents!.hasEligibleIncident) {
      _derive();
      return false;
    }
    if (_state != PeriodicPhotoGateState.due &&
        _state != PeriodicPhotoGateState.submitFailed) {
      return false;
    }
    _busy = true;
    return true;
  }

  Future<CapFormEvidence?> _capture() async {
    try {
      return await _capturePhoto();
    } on FormatException catch (error) {
      _lastError = error.message;
      _derive();
      return null;
    } on Exception catch (error) {
      _lastError = error.toString();
      _derive();
      return null;
    }
  }

  Future<void> _submitRetained() async {
    final photo = _retainedPhoto;
    if (photo == null) return;
    await _submit(photo);
  }

  bool _photoBelongsToWork(RetainedPeriodicPhoto photo) {
    if (photo.userId != _session.userId) return false;
    if (_incidents == null) return true;
    final captured = photo.capturedAt.toLocal();
    final today = _now().toLocal();
    return _incidents!.contains(photo.incidentId) &&
        captured.year == today.year &&
        captured.month == today.month &&
        captured.day == today.day;
  }

  Future<void> _submit(RetainedPeriodicPhoto photo) async {
    if (_disposed || _submitting) return;
    if (!_session.isAuthenticated || !_photoBelongsToWork(photo)) {
      await _discardRetainedPhoto();
      return;
    }
    final generation = _session.generation;
    _retainedPhoto = photo;
    _submitting = true;
    _lastError = null;
    _derive();

    // Persist before any network call: the captured photo must survive a
    // crash or a failed upload (save first, then sync).
    try {
      await _pendingRetentionClear;
      await _retainStore.write(photo);
    } on Exception {
      // Best effort: in-memory retention still protects this session, and the
      // upload below does not depend on the local write.
    }

    if (generation != _session.generation || !_photoBelongsToWork(photo)) {
      _submitting = false;
      _derive();
      return;
    }

    Result<bool> result;
    try {
      result = await _repository.submit(
        incidentId: photo.incidentId,
        evidence: photo.evidence,
      );
    } on Exception catch (error) {
      // The repository maps failures itself; this only guarantees the gate can
      // never be left stuck in `submitting`.
      result = FailureResult(UnknownFailure(error.toString()));
    }

    if (generation != _session.generation) {
      _submitting = false;
      _retainedPhoto = null;
      _derive();
      return;
    }
    switch (result) {
      case Success():
        _lastError = null;
        _retainedPhoto = null;
        await _clearRetainedPhoto();
        // Only now — after CAP confirmed — does the next deadline start.
        try {
          await _coordinator.markCompleted();
        } finally {
          _submitting = false;
          _derive();
        }
      case FailureResult(:final failure):
        // The captured photo stays (memory + disk); the user retries it
        // instead of being forced to take another one.
        _lastError = failure.message;
        _submitting = false;
        _derive();
    }
  }

  Future<void> _discardRetainedPhoto() async {
    _retainedPhoto = null;
    await _clearRetainedPhoto();
    _derive();
  }

  Future<void> _clearRetainedPhoto() async {
    try {
      await _retainStore.clear();
    } on Exception {
      // Best effort: the next capture overwrites any leftover file.
    }
  }

  PeriodicPhotoGateState _computeState() {
    if (!_session.isAuthenticated ||
        (_incidents != null && !_incidents!.hasEligibleIncident)) {
      return PeriodicPhotoGateState.disabledByConfiguration;
    }
    if (_submitting) return PeriodicPhotoGateState.submitting;
    final retained = _retainedPhoto;
    final hasRetainedPhoto = retained != null && _photoBelongsToWork(retained);
    return switch (_coordinator.snapshot.state) {
      PeriodicPhotoScheduleState.unknown => PeriodicPhotoGateState.checking,
      // A disabled configuration never blocks, regardless of anything else.
      PeriodicPhotoScheduleState.disabled =>
        PeriodicPhotoGateState.disabledByConfiguration,
      // A retained photo means the outstanding requirement was captured but
      // never confirmed by CAP: keep blocking with a retry instead of asking
      // for a second photo.
      PeriodicPhotoScheduleState.waiting =>
        !hasRetainedPhoto
            ? PeriodicPhotoGateState.waiting
            : PeriodicPhotoGateState.submitFailed,
      PeriodicPhotoScheduleState.due =>
        !hasRetainedPhoto
            ? PeriodicPhotoGateState.due
            : PeriodicPhotoGateState.submitFailed,
    };
  }

  void _derive() {
    if (_disposed || _changes.isClosed) return;
    final retained = _retainedPhoto;
    if (_incidents != null &&
        !_submitting &&
        retained != null &&
        !_photoBelongsToWork(retained)) {
      _retainedPhoto = null;
      _lastError = null;
      _pendingRetentionClear = _pendingRetentionClear.then(
        (_) => _clearRetainedPhoto(),
      );
    }
    final next = _computeState();
    final error = _lastError;
    final changed = next != _state || error != _emittedError;
    _state = next;
    _emittedError = error;
    if (changed) _changes.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _coordinatorSubscription.cancel();
    await _incidentSubscription?.cancel();
    // Deliberately not closed: nothing waits for the done event, and closing
    // after listeners have cancelled deadlocks widget-test fake async.
  }
}
