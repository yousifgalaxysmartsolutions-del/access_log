# Continuous background GPS tracking

Native continuous location capture for the CAP app, driven by system
configuration, plus upload of the locally stored points to
`CAP/CapAuth/GpsTracking`.

## Responsibility chain

```text
SystemGpsConfiguration (GetSystemConfiguration)
        ↓
GpsRequirementGate            (domain/gps_requirement_gate.dart)
        ↓                         → AppRequirementGuard (app_requirements/presentation/app_requirement_guard.dart)
        ↓                           → GpsBlockingScreen (presentation/gps_blocking_screen.dart)
GpsTrackingManager            (domain/gps_tracking_manager.dart)
        ↓
BackgroundLocationService     (domain/background_location_service.dart)
        ↓
Platform channel              (cap/background_location[+_events])
        ↓
Android: FusedLocationProviderClient + LocationForegroundService
iOS:     CLLocationManager
        ↓
LocalGpsStore                 (<applicationSupportDirectory>/cap_gps/locations.jsonl)
        ↓ event: locationCaptured
GpsCaptureSyncBridge          (domain/gps_capture_sync_bridge.dart)
        ↓
GpsTrackingSyncService        (domain/gps_tracking_sync_service.dart)
        ↓
GpsTrackingSyncRepository     (data/repositories/…_repository_impl.dart)
        ↓
GpsTrackingApiService         (CAP/CapAuth/GpsTracking)
```

Capture and upload are independent. The manager and the bridge are *not* the
engine: Android and iOS capture and persist points natively, so tracking
continues while the app is backgrounded, while the screen changes, and while
Flutter is suspended or absent. A sync failure never stops capture.

## GPS requirement gate

`continuousGpsTracking == true` makes exact GPS conditions mandatory for the
*whole* authenticated app. `GpsRequirementGate` derives a single state:

```text
checking
disabledByConfiguration          ← allows usage
permissionRequired               ← foreground location missing
backgroundPermissionRequired     ← "Always"/background missing
locationServicesDisabled         ← device Location Services off
startingTracker
ready                            ← allows usage
error
```

Only `ready` and `disabledByConfiguration` allow normal CAP usage. The state
reconciles on cold start, authenticated session, `AppLifecycleState.resumed`, a
configuration refresh, a native permission change, a Location Services change,
and an unexpected tracker stop. Reconciling re-checks Location Services,
foreground permission, background permission *and* `isTracking()` — it starts
the tracker if it is missing, and it is idempotent so no second tracker is ever
created.

`AppRequirementGuard` is mounted once in `MaterialApp.builder`, so no screen owns
the requirement; it shows `GpsBlockingScreen` (GPS first, then the periodic
photo gate). Signed-out sessions are never blocked. The screen only reads the
gate state
and forwards one intent (`Allow Location` / `Allow Background Location` / `Enable
Location` → OS settings / `Try Again`); the gate is a plain DI singleton, not a
Bloc.

## Configuration

`continuousGpsTracking` is the master switch (never hardcoded). When it is
`true` the tracker runs; when `false` it stops. `periodicGpsCaptureIntervalMinutes`
is translated into the native update strategy — there is no Dart `Timer`.
`gpsAccuracyThreshold` is carried through but not applied as a hard filter
because its unit/business meaning is not established; that policy lives in one
isolated place per platform (`GpsPointValidator`).

`GpsTrackingManager.reconcile()` runs on app start / session restore and maps
configuration to start/stop. Start/stop are idempotent at both the Dart and
native layers, so repeated calls never create a second tracker.

## Local storage

JSON Lines, one record per line, appended and `fsync`ed. An interrupted write
can at worst truncate the last line; readers skip malformed lines, so history
is never corrupted. Every accepted point is written locally whether the device
is online or offline, and `isoffline` is stamped at capture time from the
native connectivity state. It is uploaded unchanged and never recomputed.

Record shape:

```json
{"localId":"…","IncidentId":0,"LocationDateTime":"2025-09-09T12:38:49.512127",
 "TaskLatitude":"30.0972208","TaskLongitude":"31.2163613","isoffline":true}
```

`localId` and `gpsAccuracyMeters` are local-only and never sent.

## Server sync

`GpsTrackingSyncService` owns the policy; the repository owns networking only.

```text
authenticated?  ── no ──▶ keep local, stop
        │ yes
internet?       ── no ──▶ keep local, stop
        │ yes
snapshot backlog → send batch → CAP resultcode == 1?
        │                        │ no  ──▶ keep the whole batch, stop
        │ yes
        └─ delete only that batch → next batch
```

- **Success** is the CAP `resultcode == 1`, never merely HTTP 200. Anything else
  (offline, timeout, socket/HTTP error, CAP failure, parse failure) keeps the
  entire submitted batch for retry.
- **Deletion** removes exactly the `localId`s in the accepted batch (never a
  truncate/clear), and only after the response is confirmed.
- **Batching** is a snapshot of the backlog taken when the run starts, sent in
  fixed-size batches (`defaultBatchSize`, the single place it is configured).
  Points captured while a run is in flight are not part of it; they stay in the
  store and go out on the next run.
- **Single sync at a time**: `syncPending()` coalesces concurrent callers onto
  one in-flight run. A trigger that arrives while a run is active marks one
  follow-up pass instead of starting a parallel request.
- **Triggers** are centralized and near-real-time: each persisted point emits a
  native `locationCaptured` event (best-effort, after `fsync`) which
  `GpsCaptureSyncBridge` forwards to `requestSync()`; plus session
  authenticated, app resumed, "Sync now", and a backoff retry. The 5-minute
  sweep (`defaultSweepInterval`) remains only as a low-frequency safety net for
  events missed while Flutter was suspended — it is no longer the primary path.
- **Retry/backoff** lives only in `GpsTrackingSyncService`: failures and "no
  internet" retry after `5s → 15s → 30s → 60s` (capped); a successful run resets
  the sequence. A fresh trigger supersedes a scheduled retry. Retries are armed
  only while auto-sync is running, so nothing spins in a tight loop.
- **Request** reuses the shared Dio, CAP envelope, auth refresh and error
  mapping. The `data` block is `{ "IncidentId": 0, "data": [ … ] }` with
  `LocationDateTime` / `TaskLatitude` / `TaskLongitude` / `isoffline` per point.

### Store concurrency

Dart file operations are serialized by an internal mutex, and deletion rewrites
through a sibling temp file followed by an atomic `rename`, so the store is
never left truncated. The native trackers write without that lock, so deletion
also verifies the file did not grow while reading and retries if it did; a point
captured during a sync is never lost.

## Permissions

Requested only on user intent (the blocking gate's `Allow Location` /
`Allow Background Location`, `requestPermissions`, or the GPS Tracking screen),
never blindly at startup or on every resume. Android requests foreground →
notifications → background in sequence; iOS requests when-in-use → always.
Denials surface as gate states so the UI can guide the user; permission prompts
are never looped.

Location Services are monitored natively and event-driven — no Dart polling.
Android registers a `LocationManager.PROVIDERS_CHANGED_ACTION` receiver in the
bridge and emits `locationServicesDisabled` / `permissionChanged`; iOS re-emits
the status on `didBecomeActive` and via `locationManagerDidChangeAuthorization`.
Turning GPS back on produces a native event → config-free reconcile → the gate
auto-clears and tracking resumes, with no re-login or manual button. `openLocationSettings`
(Android `ACTION_LOCATION_SOURCE_SETTINGS`, iOS app Settings) is offered as the
resolution flow; the app never enables Location Services silently.

## Tests

- `test/gps_tracking_manager_test.dart` — configuration start/stop, idempotent
  start, restart reconciliation, permission gating.
- `test/gps_requirement_gate_test.dart` — config off → allowed; ready → allowed;
  GPS off / foreground missing / background missing → blocked; tracker stopped →
  restarted; GPS off→on and permission revoked→restored auto-clear; resume
  reconcile; repeated reconcile adds no second tracker.
- `test/local_gps_store_test.dart` — durable persistence, online/offline flags,
  truncated-line resilience, CAP payload shape, atomic `removeByIds`.
- `test/gps_configuration_test.dart` — system-config parsing and fail-closed
  defaults.
- `test/gps_tracking_sync_service_test.dart` — offline/auth gates, success and
  failure retention, partial queue, mid-sync captures, `isoffline`, single-flight
  sync, immediate new-point trigger, backlog drain, backoff retry and reset.
- `test/gps_capture_sync_bridge_test.dart` — `locationCaptured` → immediate
  sync, idempotent subscription, other events ignored.
- `test/gps_tracking_sync_repository_test.dart` — CAP envelope, exact point
  shape, `resultcode == 1` success condition, unauthorized handling.
