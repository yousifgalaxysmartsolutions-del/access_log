# CAP dynamic forms

This feature adapts STC's question type IDs and conditional-question behavior to
Access Log+'s CAP envelope, Result/Failure, authenticated Dio, localization and
screen-scoped Bloc/Cubit architecture. It does not import STC application code,
authentication, offline database, themes or background services.

## Integration entry point

Use `CapIncidentFormScreen` with caller-provided `formId`, `incidentId`,
`newStatusId`, and `actionTypeId`. No form IDs or transitions are inferred.
Await the route's boolean result; `true` means the CAP submission succeeded, so
the caller should refresh GetIncidentDetails. Cancellation returns false/null.
The screen never updates an incident's status locally. Set `requireRemark`
explicitly when the workflow requires it.

`CapDynamicForm` can also be embedded independently with a caller-owned cubit,
capture callback, retry callback and validated-answer callback. Its confirmation
does not call an API. `CapIncidentFormScreen` provides the submission coordinator.

## Implemented

- GetFormQuestion and IncidentStatusChange Retrofit endpoints; shared session,
  auth, error mapping, CAP context and redacted logging.
- Required fields, numeric/GPS/date/rating/choice validation, conditional fields,
  nested visibility and hidden-answer removal.
- STC types 1,2,3,4,5,6,7,8,9,10,11,13,14. Unknown types block confirmation.
- Foreground camera photo/video, microphone recording, QR/barcode scanning,
  one-shot location, manual code/location input, PNG signature drawing/clearing,
  image preview and removal. Permissions are requested on user interaction.
- Evidence limited to 16 MiB; video capture 30 seconds, audio 60 seconds.
  Audio stops when the app becomes inactive. Only screen-owned temporary audio
  files are cleaned up. Evidence is held in memory, not uploaded automatically.
- Single-flight submission; inputs remain intact on failures; explicit retry;
  success result; unsaved-change confirmation; no auto-retry of mutations.
- Arabic/English, directional layout, scalable text, theme-aware controls.

## Confirmed action execution contract

Incident Details now opens the shared action-configuration coordinator with the
real IncidentId and the selected resolver action. Requirements are collected once
into IncidentExecutionContext. Assign continues to team selection and
AssignIncident; other supported actions reuse this feature's IncidentStatusChange.
The embedded form only collects answers; it never submits them separately.

- No form: QuestionFormId is null and Answers is empty.
- Top-level lat/long are separate strings; GPS form answers remain unchanged.
- Top-level photo is Base64; AnswerBytes contains raw bytes (JSON integer array).
- Captured form evidence uses the existing answer serializer.
- Each selected multi-choice option is a separate answer for the same parent
  QuestionId, with its own OptionAnswer ID.
- Failed execution retains the context; retry is explicit. Successful execution
  returns true to Incident Details and refreshes server data.

No production endpoints were called during development. Automated tests use
fake transports/capture callbacks. Physical camera, microphone, scanner and GPS
must be acceptance-tested on Android/iOS devices with granted/denied permissions.
Native plugin changes require a full rebuild, not hot reload. No background
location, background audio or broad storage permission is requested.
