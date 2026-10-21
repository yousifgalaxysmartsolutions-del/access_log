# Periodic mandatory photo capture

Config-driven, app-level requirement: when `enablePhotoCapture` is on and the
current user has eligible In Process work today, the user must take a photo
every `periodicPhotoCaptureIntervalMinutes` before CAP usage
is allowed. Both values come from `CAP/CapConfiguration/GetSystemConfiguration`
— no interval is ever hardcoded in the app.

## Responsibility chain

```text
SystemGpsConfiguration (GetSystemConfiguration — photo block)
        ↓
PeriodicPhotoCoordinator      (domain/periodic_photo_coordinator.dart)
        ↓                         timing policy: persisted deadline, wake timer
PeriodicPhotoGate             (domain/periodic_photo_gate.dart)
        ↓                         requirement lifecycle: due → capture → submit
AppRequirementGuard           (app_requirements/presentation/…)
        ↓                         one root overlay, GPS first then photo
PeriodicPhotoBlockingScreen   (presentation/periodic_photo_blocking_screen.dart)
        ↓ user taps "Take Photo"
CapNativeFormCapture.capturePhoto()   (forms feature — camera, 16 MB guard)
        ↓
PeriodicPhotoRepository       (data/repositories/…_repository_impl.dart)
        ↓
CAP/CapIncident/SavePeriodicPhoto
```

Timing policy, config policy, API logic and UI are strictly separated:

| Layer | Owns | Never does |
| --- | --- | --- |
| `PeriodicPhotoCoordinator` | interval from config, persisted `lastPeriodicPhotoAt`/`nextPhotoDueAt`, single wake timer | network calls, UI, incident context |
| `PeriodicPhotoGate` | requirement state machine, capture/upload intents, photo retention | timers, config parsing, widget code |
| `AppRequirementGuard` | which single blocking screen shows (GPS > photo), session wiring | requirement logic |
| `PeriodicPhotoBlockingScreen` | rendering state + forwarding taps | anything else |

## Behaviors

* **Disabled** (`enablePhotoCapture == false`, or no usable interval): no
  schedule, no gate, no camera. A failed configuration read never invents a
  requirement (fail closed) and never blocks usage.
* **Deadline**: absolute and persisted at
  `<applicationSupportDirectory>/cap_photo/schedule.json`. A restart or
  background period resumes the *same* window — it never restarts the
  interval. The next deadline starts only after CAP confirms a photo
  (`resultcode == 1`), so windows never overlap.
* **Multiple missed intervals** produce exactly one overdue requirement on
  resume — never a stack of gates.
* **Camera** opens only from a user tap on the blocking screen; never on a
  deadline, on resume, or from the background. Cancelling keeps the
  requirement due.
* **Upload failure** never forces a second photo: the captured image is kept
  in memory *and* on disk (`<applicationSupportDirectory>/cap_photo/`), the
  gate shows Retry/Retake, and a reconcile auto-retries the **same** photo once.
  Retention is restored only for the same signed-in user.
* **Payload**: `IncidentId` (from `ActiveIncidentContext.uploadIncidentId`,
  `0` outside an incident), `ImageData` (real detected extension, `jpg`/`png`),
  `ImageBytes` (raw bytes as a JSON array, matching the `AnswerBytes`
  contract style — `AnswerBytes` itself is never sent).
* **Priority**: `AppRequirementGuard` shows at most one blocking screen —
  GPS first, then the photo requirement. Signed-out sessions are never
  blocked.

## Reconcile triggers

Cold start (`main.dart`), authenticated session, configuration refresh,
`AppLifecycleState.resumed` (both in `app.dart` and the guard's session
listener) and the armed deadline timer — always single-flight/coalesced,
never a poll loop.

## Tests

* `test/periodic_photo_configuration_test.dart` — fail-closed `photo` parsing
* `test/periodic_photo_coordinator_test.dart` — deadlines, restart, background,
  interval changes, single-flight/single-timer
* `test/periodic_photo_gate_test.dart` — due/capture/submit, retention,
  retry-without-retake, incident context
* `test/periodic_photo_api_test.dart` — exact wire contract
  (`IncidentId`/`ImageData`/`ImageBytes`, extension from bytes, envelope)
* `test/app_requirement_guard_test.dart` — GPS-first priority, one overlay
* `test/active_incident_context_test.dart` — stack semantics, no stale ids
* `test/today_in_process_incident_test.dart` — eligibility, persistence, ordering,
  safe reconciliation, account/day isolation and work-scoped photo timing

## Today / In Process eligibility cache

Production photo eligibility and upload `IncidentId` now come from
`TodayInProcessIncidentService`, not the incident route currently open.

* Only a **successful action initiated by this user** updates the work cache.
  Normal GetIncidentList and GetIncidentDetails reads never enroll/remove work.
* Explicit incident status changes add In Process (4) or remove other statuses.
  After Entry/Un Hold succeeds, the specific incident's details verify the real
  incident status and signed-in assignee. Request NewStatusId is never treated
  as an incident status. Failed mutation/verification never invents active work.
* Renewal alone cannot enroll work started elsewhere. Repeating actions on
  already-active work preserves its order; leaving and re-entering ranks anew.
* Cache file: `<applicationSupportDirectory>/cap_photo/in_process_today.json`.
  User/day scope prevents yesterday's/another user's work from enabling photos.
  Version 2 ignores old list-populated cache records.
* Timers stop when no eligible work exists. Reactivation starts a new interval;
  same-user/day restarts with active work retain the persisted deadline.
* Latest means the last successful local transition, not incident creation time.
  Account changes, midnight and newer actions invalidate stale in-flight results.
* External changes from another device or supervisor are deliberately **not**
  synchronized under this local-only policy. A failed post-action verification
  cannot confirm unknown server status; there is no background incident polling.
* A single camera intent uploads against the latest eligible ID at capture time.
  Retries keep the original captured photo/ID; removed IDs or old-day/other-user
  photos are never automatically retried against a different incident.
