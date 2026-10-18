import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/background_location_service.dart';
import '../domain/gps_tracking_manager.dart';
import '../domain/gps_tracking_sync_service.dart';

/// Read-only view of tracking state for the UI. It never owns the engine.
class GpsTrackingViewState {
  const GpsTrackingViewState({
    this.status = GpsTrackingStatus.unknown,
    this.permission = LocationPermissionStatus.unknown,
    this.nativeTracking = false,
    this.busy = false,
    this.syncStatus = GpsSyncStatus.idle,
    this.pendingCount = 0,
  });

  final GpsTrackingStatus status;
  final LocationPermissionStatus permission;
  final bool nativeTracking;
  final bool busy;

  /// Read-only view of the sync service; the UI never drives sync directly.
  final GpsSyncStatus syncStatus;

  /// Points waiting to be uploaded.
  final int pendingCount;

  GpsTrackingViewState copyWith({
    GpsTrackingStatus? status,
    LocationPermissionStatus? permission,
    bool? nativeTracking,
    bool? busy,
    GpsSyncStatus? syncStatus,
    int? pendingCount,
  }) => GpsTrackingViewState(
    status: status ?? this.status,
    permission: permission ?? this.permission,
    nativeTracking: nativeTracking ?? this.nativeTracking,
    busy: busy ?? this.busy,
    syncStatus: syncStatus ?? this.syncStatus,
    pendingCount: pendingCount ?? this.pendingCount,
  );
}

/// Presents [GpsTrackingManager] status and forwards user intents.
class GpsTrackingCubit extends Cubit<GpsTrackingViewState> {
  GpsTrackingCubit(this._manager, {GpsTrackingSyncService? sync})
    : _sync = sync,
      super(const GpsTrackingViewState()) {
    _subscription = _manager.changes.listen((status) {
      _publish(_state.copyWith(status: status));
    });
    _syncSubscription = _sync?.changes.listen((status) {
      _publish(_state.copyWith(syncStatus: status));
      unawaited(_refreshPendingCount());
    });
    refresh();
  }

  final GpsTrackingManager _manager;
  final GpsTrackingSyncService? _sync;
  StreamSubscription<GpsTrackingStatus>? _subscription;
  StreamSubscription<GpsSyncStatus>? _syncSubscription;
  GpsTrackingViewState _state = const GpsTrackingViewState();

  Future<void> refresh() async {
    final permission = await _manager.permissionStatus();
    final nativeTracking = await _manager.isNativeTracking();
    _publish(
      _state.copyWith(
        status: _manager.status,
        permission: permission,
        nativeTracking: nativeTracking,
        syncStatus: _sync?.status,
      ),
    );
    await _refreshPendingCount();
  }

  /// User-triggered: request permissions and start if possible.
  Future<void> enable() async {
    _publish(_state.copyWith(busy: true));
    await _manager.enableTracking();
    await refresh();
    _publish(_state.copyWith(busy: false));
  }

  Future<void> stop() async {
    _publish(_state.copyWith(busy: true));
    await _manager.stopTracking();
    await refresh();
    _publish(_state.copyWith(busy: false));
  }

  Future<void> reconcile() async {
    _publish(_state.copyWith(busy: true));
    await _manager.reconcile();
    await refresh();
    _publish(_state.copyWith(busy: false));
  }

  /// User-triggered sync request. It only asks the service to run; the service
  /// still applies the connectivity/auth/permission gates and its own lock.
  Future<void> syncNow() async {
    final sync = _sync;
    if (sync == null) return;
    await sync.syncPending();
    await _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final sync = _sync;
    if (sync == null) return;
    final count = await sync.pendingCount();
    _publish(_state.copyWith(pendingCount: count, syncStatus: sync.status));
  }

  void _publish(GpsTrackingViewState value) {
    _state = value;
    if (!isClosed) emit(value);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _syncSubscription?.cancel();
    return super.close();
  }
}
