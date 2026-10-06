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

## Contract boundaries awaiting the next specification

1. Which incident buttons open this screen and where their FormId comes from.
2. CAP binary encoding: supplied samples only show AnswerBytes:null. STC uses
   different field names/encodings, so they are not assumed compatible. Captured
   files are `CapFormEvidence` (immutable bytes/name/MIME), separate from the wire
   DTO. `encodeAnswers` is the explicit extension point for the confirmed CAP
   encoding. Without it, evidence submission fails locally, retaining the file.
3. CAP multi-selection encoding: the sample has scalar OptionAnswer. Multiple
   selections work locally but are blocked from submission until documented.

No production endpoints were called during development. Automated tests use
fake transports/capture callbacks. Physical camera, microphone, scanner and GPS
must be acceptance-tested on Android/iOS devices with granted/denied permissions.
Native plugin changes require a full rebuild, not hot reload. No background
location, background audio or broad storage permission is requested.
