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
/// * the UI - sync runs from lifecycle/auth triggers, never from a screen.
///
/// Invariants enforced here:
/// * records are only removed after CAP confirms success for that exact batch;
/// * only one sync runs at a time ([syncPending] coalesces callers);
/// * no API call is made without internet and an authenticated session.
class GpsTrackingSyncService {
  GpsTrackingSyncService({
    required GpsPendingStore store,
    required GpsTrackingSyncRepository repository,
    required ConnectivityService connectivity,
    required SessionManager session,
    this.batchSize = defaultBatchSize,
    this.sweepInterval = defaultSweepInterval,
  }) : _store = store,
       _repository = repository,
       _connectivity = connectivity,
       _session = session;

  /// Maximum records per `GpsTracking` request. The only place batch sizing is
  /// decided.
  static const int defaultBatchSize = 200;

  /// Conservative sweep used to notice "internet restored" or "a new point was
  /// captured" without a platform connectivity stream and without an aggressive
  /// retry loop.
  static const Duration defaultSweepInterval = Duration(minutes: 5);

  final GpsPendingStore _store;
  final GpsTrackingSyncRepository _repository;
  final ConnectivityService _connectivity;
  final SessionManager _session;

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

  /// Fire-and-forget entry point for lifecycle triggers.
  ///
  /// Sync failures are already handled inside [syncPending]; this only exists so
  /// callers do not have to await the result.
  void requestSync() {
    unawaited(syncPending().catchError((Object _) {}));
  }

  Future<void> _run() async {
    try {
      // 1. Authentication gate: never send when signed out, and keep the data.
      if (!_session.isAuthenticated) {
        _emit(GpsSyncStatus.unauthenticated);
        return;
      }
      // 2. Connectivity gate: never call the API while offline.
      if (!await _connectivity.hasInternet()) {
        _emit(GpsSyncStatus.offline);
        return;
      }

      _emit(GpsSyncStatus.syncing);
      var uploaded = 0;

      // 3. Snapshot the backlog once, then send it in batches. Points captured
      //    while this run is in flight are deliberately *not* part of it; they
      //    stay in the store and are picked up by the next trigger. This is what
      //    guarantees a mid-sync capture can never be deleted or lost.
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
            // Keep every record; the next trigger retries.
            _lastUploaded = uploaded;
            _emit(GpsSyncStatus.failed);
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

      _lastUploaded = uploaded;
      _emit(uploaded > 0 ? GpsSyncStatus.synced : GpsSyncStatus.idle);
    } on Object {
      // Storage or unexpected errors: keep everything and report failure.
      _lastUploaded = 0;
      _emit(GpsSyncStatus.failed);
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
    _sweep ??= Timer.periodic(sweepInterval, (_) => requestSync());
    requestSync();
  }

  /// Stops the sweep (does not stop tracking and deletes nothing).
  void stopAutoSync() {
    _sweep?.cancel();
    _sweep = null;
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
