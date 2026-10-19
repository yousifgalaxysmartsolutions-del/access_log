import 'dart:async';

import 'background_location_service.dart';
import 'gps_tracking_sync_service.dart';

/// Bridges the native "a point was captured" signal to the sync service.
///
/// ```text
/// native GPS → LocalGpsStore append (fsync) → event: locationCaptured
///                                                        ↓
///                                              GpsCaptureSyncBridge
///                                                        ↓
///                                        GpsTrackingSyncService.requestSync()
/// ```
///
/// The native engine emits [GpsTrackingEventType.locationCaptured] only *after*
/// the point has been persisted, and it emits best-effort (a missing Flutter
/// listener changes nothing). So:
///
/// * capture/persistence never wait on Dart or on a network round trip;
/// * when no engine is alive the event is simply lost, and the point is picked
///   up by the next trigger (app resume, auth, sweep, or the next captured
///   point);
/// * the sync service keeps its own single-flight/backoff rules, so a burst of
///   points never produces parallel uploads.
///
/// This class owns no policy of its own: it only forwards the trigger.
class GpsCaptureSyncBridge {
  GpsCaptureSyncBridge(this._service, this._sync);

  final BackgroundLocationService _service;
  final GpsTrackingSyncService _sync;

  StreamSubscription<GpsTrackingEvent>? _subscription;
  bool _started = false;

  /// Subscribes once. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _subscription = _service.events.listen(
      (event) {
        if (event.type == GpsTrackingEventType.locationCaptured) {
          _sync.requestSync();
        }
      },
      onError: (Object _) {},
      onDone: () {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
