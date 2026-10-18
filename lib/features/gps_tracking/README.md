# Continuous background GPS tracking

Native continuous location capture for the CAP app, driven by system
configuration, plus upload of the locally stored points to
`CAP/CapAuth/GpsTracking`.

## Responsibility chain

```text
SystemGpsConfiguration (GetSystemConfiguration)
        ↓
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

LocalGpsStore
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
  one in-flight run.
- **Triggers** are centralized: app start, session authenticated, app resumed,
  and a conservative sweep (`defaultSweepInterval`) that notices "internet
  restored" / "a new point captured". No aggressive retry loop.
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

Requested only on user intent (`requestPermissions` / the GPS Tracking screen),
never blindly at startup. Android requests foreground → notifications →
background in sequence; iOS requests when-in-use → always. Denials surface as
`awaitingPermission` / `error` so the UI can guide the user; permission prompts
are never looped. Sync itself requires no permission and never prompts.

## Tests

- `test/gps_tracking_manager_test.dart` — configuration start/stop, idempotent
  start, restart reconciliation, permission gating.
- `test/local_gps_store_test.dart` — durable persistence, online/offline flags,
  truncated-line resilience, CAP payload shape, atomic `removeByIds`.
- `test/gps_configuration_test.dart` — system-config parsing and fail-closed
  defaults.
- `test/gps_tracking_sync_service_test.dart` — offline/auth gates, success and
  failure retention, partial queue, mid-sync captures, `isoffline`, single-flight
  sync.
- `test/gps_tracking_sync_repository_test.dart` — CAP envelope, exact point
  shape, `resultcode == 1` success condition, unauthorized handling.
