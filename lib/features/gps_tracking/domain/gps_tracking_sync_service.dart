import 'dart:async';

import '../../../core/network/result.dart';
import '../../../core/session/session_manager.dart';
import 'connectivity_service.dart';
import 'gps_location_record.dart';
import 'gps_pending_store.dart';
import 'repositories/gps_tracking_sync_repository.dart';

/// Read-only synchronization status, for display only. The UI never owns or
/// drives the sync process.
enum GpsSyncStatus {
  /// Nothing pending (or nothing to do).
  idle,

  /// A sync is currently running.
  syncing,

  /// The last run uploaded at least one batch.
  synced,

  /// Skipped: no internet.
  offline,

  /// Skipped: no authenticated CAP session.
  unauthenticated,

  /// The last run failed; the batch was kept for retry.
  failed,
}

/// Uploads locally stored GPS points to the server.
///
/// This is the single place that decides *whether*, *how much* and *when* to
/// sync. It is deliberately independent of:
///
/// * the native tracking engine - a sync failure never stops capture;
/// * the UI - sync runs from lifecycle/auth/point triggers, never from a screen.
///
/// Invariants enforced here:
/// * records are only removed after CAP confirms success for that exact batch;
/// * only one sync runs at a time ([syncPending] coalesces callers);
/// * no API call is made without internet and an authenticated session;
/// * retries are controlled by a capped backoff, never an immediate tight loop.
class GpsTrackingSyncService {
  GpsTrackingSyncService({
    required GpsPendingStore store,
    required GpsTrackingSyncRepository repository,
    required ConnectivityService connectivity,
    required SessionManager session,
    this.batchSize = defaultBatchSize,
    this.sweepInterval = defaultSweepInterval,
    List<Duration>? retryDelays,
  }) : _store = store,
       _repository = repository,
       _connectivity = connectivity,
       _session = session,
       _retryDelays = retryDelays ?? defaultRetryDelays;

  /// Maximum records per `GpsTracking` request. The only place batch sizing is
  /// decided.
  static const int defaultBatchSize = 200;

  /// Conservative sweep used as a safety net for events that were missed while
  /// Flutter was suspended. It is no longer the primary mechanism: a new point
  /// triggers an immediate attempt and failures schedule a backoff retry.
  static const Duration defaultSweepInterval = Duration(minutes: 5);

  /// Controlled retry backoff. Failures (and "no internet") retry after the
  /// next delay, capped at the last value; a successful run resets the sequence.
  /// Kept here so the retry strategy lives in exactly one place.
  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final GpsPendingStore _store;
  final GpsTrackingSyncRepository _repository;
  final ConnectivityService _connectivity;
  final SessionManager _session;
  final List<Duration> _retryDelays;

  /// Isolated, configurable batch size.
  final int batchSize;

  /// Isolated, configurable sweep interval.
  final Duration sweepInterval;

  final _changes = StreamController<GpsSyncStatus>.broadcast();

  /// Status changes, for read-only display.
  Stream<GpsSyncStatus> get changes => _changes.stream;

  GpsSyncStatus _status = GpsSyncStatus.idle;
  GpsSyncStatus get status => _status;

  int _lastUploaded = 0;

  /// Number of points uploaded by the most recent successful run.
  int get lastUploaded => _lastUploaded;

  Future<void>? _running;
  bool _pending = false;
  Timer? _sweep;

  /// Retry backoff state. Only armed while [startAutoSync] is active so a
  /// directly-awaited [syncPending] (tests, one-off calls) never leaves timers
  /// behind.
  Timer? _retry;
  int _retryAttempt = 0;
  bool _autoSyncActive = false;

  /// Points still waiting to be uploaded.
  Future<int> pendingCount() => _store.count();

  /// Runs the pending-sync loop, at most one instance at a time.
  ///
  /// Concurrent calls (`sync()`, `sync()`, `sync()`) all await the same in-flight
  /// run instead of starting another. A call that arrives while a run is active
  /// marks a follow-up run, so the trigger is never silently dropped.
  Future<void> syncPending() {
    final active = _running;
    if (active != null) {
      _pending = true;
      return active;
    }
    final started = _drain();
    _running = started;
    return started;
  }

  Future<void> _drain() async {
    do {
      _pending = false;
      await _run();
    } while (_pending);
    _running = null;
  }

  /// Fire-and-forget entry point for every trigger:
  ///
  /// * a new point was persisted locally (native `locationCaptured` event);
  /// * internet restored / app resumed / session authenticated;
  /// * the backoff retry timer fired;
  /// * the user asked to sync now.
  ///
  /// A fresh trigger supersedes a scheduled retry. Failures are already handled
  /// inside [syncPending]; this only exists so callers do not have to await.
  void requestSync() {
    _cancelRetry();
    unawaited(syncPending().catchError((Object _) {}));
  }

  Future<void> _run() async {
    _cancelRetry();
    try {
      // 1. Authentication gate: never send when signed out, and keep the data.
      //    The auth trigger will pick this up when a session becomes available.
      if (!_session.isAuthenticated) {
        _emit(GpsSyncStatus.unauthenticated);
        return;
      }
      // 2. Connectivity gate: never call the API while offline. A capped retry
      //    notices "internet restored" without an aggressive loop.
      if (!await _connectivity.hasInternet()) {
        _emit(GpsSyncStatus.offline);
        _scheduleRetry();
        return;
      }

      _emit(GpsSyncStatus.syncing);
      var uploaded = 0;

      // 3. Snapshot the backlog once, then send it in batches. Points captured
      //    while this run is in flight are deliberately *not* part of it; they
      //    stay in the store and are picked up by the next trigger (the native
      //    `locationCaptured` event fires for them). This is what guarantees a
      //    mid-sync capture can never be deleted or lost.
      final pending = await _store.readAll();
      var index = 0;
      while (index < pending.length) {
        if (!_session.isAuthenticated) break;

        final batch = _takeBatch(pending, index);
        if (batch.isEmpty) break;

        final result = await _repository.upload(
          incidentId: batch.first.incidentId,
          records: batch,
        );

        switch (result) {
          case FailureResult():
            // Keep every record; a backoff retry (or the next point) retries.
            _lastUploaded = uploaded;
            _emit(GpsSyncStatus.failed);
            _scheduleRetry();
            return;
          case Success():
            // Delete only the points from this accepted batch. Points captured
            // while the request was in flight stay in the store.
            await _store.removeByIds(
              batch.map((record) => record.localId).toSet(),
            );
            uploaded += batch.length;
            index += batch.length;
        }
      }

      // A completed run (even "nothing to do") proves the path is healthy, so
      // the next failure starts the backoff from the beginning again.
      _resetRetry();
      _lastUploaded = uploaded;
      _emit(uploaded > 0 ? GpsSyncStatus.synced : GpsSyncStatus.idle);
    } on Object {
      // Storage or unexpected errors: keep everything and retry with backoff.
      _lastUploaded = 0;
      _emit(GpsSyncStatus.failed);
      _scheduleRetry();
    }
  }

  /// The next contiguous run of at most [batchSize] records starting at [start]
  /// that share one `IncidentId`.
  ///
  /// Continuous tracking stores a single `IncidentId` (0), so a batch is
  /// normally just the next [batchSize] points. Keeping a batch to one
  /// `IncidentId` keeps the per-request `IncidentId` correct even if storage
  /// ever holds more than one.
  List<GpsLocationRecord> _takeBatch(
    List<GpsLocationRecord> pending,
    int start,
  ) {
    final incidentId = pending[start].incidentId;
    var end = start;
    while (end < pending.length &&
        end - start < batchSize &&
        pending[end].incidentId == incidentId) {
      end++;
    }
    return pending.sublist(start, end);
  }

  /// Starts the conservative sweep and attempts an immediate sync.
  ///
  /// Safe to call once at app start. The sweep only syncs when there are
  /// authenticated pending records and internet is available.
  void startAutoSync() {
    _autoSyncActive = true;
    _sweep ??= Timer.periodic(sweepInterval, (_) => requestSync());
    requestSync();
  }

  /// Stops the sweep and the backoff retry (does not stop tracking and deletes
  /// nothing).
  void stopAutoSync() {
    _autoSyncActive = false;
    _sweep?.cancel();
    _sweep = null;
    _cancelRetry();
  }

  /// Arms the next backoff retry. No-op unless auto-sync is running, so
  /// one-off [syncPending] calls never leave timers behind.
  void _scheduleRetry() {
    if (!_autoSyncActive || _retryDelays.isEmpty) return;
    final index = _retryAttempt < _retryDelays.length
        ? _retryAttempt
        : _retryDelays.length - 1;
    _retryAttempt++;
    _retry?.cancel();
    _retry = Timer(_retryDelays[index], () {
      _retry = null;
      requestSync();
    });
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void _resetRetry() {
    _cancelRetry();
    _retryAttempt = 0;
  }

  void _emit(GpsSyncStatus value) {
    _status = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() async {
    stopAutoSync();
    await _changes.close();
  }
}
