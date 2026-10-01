# Mobile application foundation

Existing screens remain in `lib/screens` and existing widgets remain in `lib/widgets`.

```text
lib/core/
  config/environment.dart
  di/injection.dart
  error/{failure,exception_mapper}.dart
  network/{dio_client,api_endpoints,api_response,result,upload_api_service}.dart
  network/interceptors/{auth_interceptor,logging_interceptor}.dart
  session/session_manager.dart
  storage/secure_storage_service.dart
lib/features/
  authentication/
    data/api/auth_api_service.dart
    data/models/auth_models.dart
    data/repositories/auth_repository_impl.dart
    domain/repositories/auth_repository.dart
    domain/usecases/login_use_case.dart
    presentation/bloc/login_bloc.dart
  copilot/
    data/api/copilot_api_service.dart
    data/{copilot_repository,retrofit_ai_transport}.dart
    domain/complete_copilot_use_case.dart
```

## Running

`flutter run` now uses the CAP test login endpoint by default:
`https://test.talentlink360.com/Developmnet/BridgeForce_Dev/BridgeFoce_API_Dev/api/CAP/CapAuth/Login`.
Use `flutter run --dart-define=MOCK_AUTH=true` to restore demo authentication.
All non-authentication workflows still use mock data.

CAP request metadata defaults exactly to the supplied test fixture (including
device type iOS and OS 15.1). Override CAP_DEVICE_ID, CAP_DEVICE_TOKEN,
CAP_OS_VERSION, CAP_APP_VERSION, CAP_DEVICE_TYPE, CAP_LANGUAGE with dart-define.
These are test metadata, not detected device information or real push tokens.
Credentials come only from the existing login inputs and are not stored in source.
Android debug builds allow HTTP only to the specified test IP. No broad cleartext
exception was added to release builds. Apple ATS HTTP behavior must be verified on
the target iPhone; use HTTPS for production.

The login parser now follows the supplied CAP response: resultcode must equal 1;
data contains User_PK_ID, User_Name, AccessToken and RefreshToken. Explicitly
disabled mobile accounts are rejected. Both tokens are saved via SessionManager.
CAP refresh was not supplied, so no requests are made to an invented refresh
endpoint. Expiry/biometric fields do not trigger new timers or biometric setup.
This mapping is verified with synthetic fixtures, not the user's real tokens.

Backend authentication is opt-in; no authentication backend contract was supplied.
The following example expects a backend implementing the contract below:

```sh
flutter run --dart-define=APP_ENV=staging --dart-define=MOCK_AUTH=false \
  --dart-define=API_BASE_URL=https://your-backend.example/api \
  --dart-define=API_VERSION=v1
```

Use `development`, `staging`, or `production` for APP_ENV. Pass that environment's
API_BASE_URL/API_VERSION in its build configuration. There are deliberately no
invented production servers. Debug builds log request/response/error URL, status,
headers and JSON bodies by default. Passwords, tokens, authorization, cookies and
secret fields are recursively redacted. Large bodies are truncated and file bytes
are omitted. Use API_LOGGING=false to disable; release builds never log.

## Authentication contract to confirm with backend

The former generic contract below is historical. CAP now sends the provided
envelope with userid, ipaddress, devicetoken, osversion, AppVersion, devicetype,
lang and nested data containing UserName and Password.

Former POST auth/login: `{ "username": "…", "password": "…" }`

Response: `{ "accessToken": "…", "refreshToken": "…", "user": { "id": "…", "name": "…" } }`

POST auth/refresh: `{ "refreshToken": "…" }`

Response: `{ "accessToken": "…", "refreshToken": "…" }`

Adjust these endpoint names/model mappings to the actual backend before enabling
live authentication. Password recovery and biometric screens remain prototype
flows; the biometric button cannot bypass password authentication in live mode.

Login screen → LoginBloc → LoginUseCase → AuthRepository → generated AuthApiService
→ shared Dio. AuthRepository selects demo or live implementation at startup.

## Sessions and refresh

Temporary TLS exception: at the user's request, mobile Debug/Profile/Release builds
accept invalid certificates only for `test.talentlink360.com:443` through the CAP
Dio adapter. Other hosts (including Groq) retain normal certificate verification.
This disables server identity verification for that host and must be removed once
the certificate chain is repaired. Disable with
`--dart-define=CAP_ALLOW_INVALID_CERTIFICATE=false` and rebuild the application.
No global HttpOverrides or platform-wide certificate bypass is installed.

SessionManager owns in-memory credentials, serialized secure persistence, restore,
logout and expiration. Remember Me=false avoids persisting credentials. A refresh
uses a separate Dio transport to prevent interceptor recursion. Protected requests
wait for the shared refresh future. Concurrent/stale 401 responses reuse the new
token; a request retries only once. Refresh failure clears the session and the app
removes authenticated navigation history. A session generation prevents late
refresh results from restoring a session after logout. Streams are not replayed;
FormData is cloned. Cancelled requests are not replayed.

All backend services share the DI Dio singleton. Mark public Retrofit methods
with `@Extra({'public': true})`. Protected calls refuse cross-origin URLs and calls
without an authenticated session. Do not mark protected endpoints public.

The Groq client is isolated from application credentials: provider keys never go
through the application refresh interceptor. Supply GROQ_API_KEY externally for
the existing provider mode; without it the existing mock mode remains available.
Mobile builds cannot keep a provider key secret; use a backend proxy for a public
production release.

## Migrated existing API

Existing Copilot UI → AiCopilotController (Cubit) → CompleteCopilotUseCase →
CopilotRepository → existing prompt/fallback service → RetrofitAiTransport →
generated CopilotApiService → Dio → existing Groq endpoint.

Existing context building, fallback model behavior, injected test clients and UI
remain intact. The former HttpClient transport is retained only for compatibility;
the default execution path uses Retrofit/Dio. Repository errors become Result.

## New endpoints

1. Add a Retrofit service under the feature's data/api directory.
2. Reuse a simple model where no separate domain representation is needed.
3. Wrap repository operations with apiGuard; map results before returning Success.
4. Add a focused use case and Bloc/Cubit only for the feature behavior.
5. Register service/repository/use case lazily and Bloc as a factory in injection.dart.

UploadApiService is a generated, unused template demonstrating multipart files,
query parameters, dynamic request headers, cancellation and progress. Confirm its
endpoint with the backend before wiring it into existing evidence UI.

```sh
dart run build_runner build
flutter analyze
flutter test test/network_foundation_test.dart test/ai_copilot_test.dart
```

Generated `.g.dart` files belong in source control. Secure storage requires platform
plugin setup from flutter_secure_storage for the target distribution. Verify
Keychain entitlements for Apple builds and Android backup behavior on real devices.
No real login or refresh requests are executed in unit tests.

Modified existing files: pubspec.yaml/lock, main.dart, app.dart, core/routes/app_routes.dart,
screens/auth/auth_screens.dart, widgets/session_timeout_ui.dart and the Copilot
service/controller/screen. New foundation files are listed above. No existing
screens were moved or redesigned.

## Incident list integration

`IncidentListScreen` now owns one `IncidentListBloc`, resolving the existing
`GetIncidentListUseCase` from DI. It reuses `IncidentRepositoryImpl`, Retrofit,
the CAP envelope/context, DTO parser and `IncidentMapper`; no parallel API stack
or widget JSON parsing was added. Missing DI shows an error, not demo incidents.
The existing explicit mock-auth DI configuration remains unchanged.

The existing single-day repository/use-case method accepts an optional `toDate`
for ranges, keeping dashboard callers compatible. No date filter means the local
current day; one bound means that single day. Invalid ranges are rejected.
Only date changes or refresh/retry trigger a new fetch; search, status, priority,
region, area, site, number, type and location are matched locally. The DTO's
existing filter defaults remain untouched. Reset restores today; removing the
status chip preserves the other filters.

The existing request DTO already supports `Page` and `PageSize`. The repository
collects pages until `totalCount` is satisfied and rejects repeated/nonadvancing
pages instead of silently presenting a partial collection. This behavior is
covered by adapter tests, but has not been verified against a live multi-page
server response. No new request keys or status/priority ID assumptions were added.

CAP's observed list response has no incident timestamp. `hasRealDate` records
whether the mapper actually received one; cards show “Date unavailable” otherwise.
Newest/oldest preserve backend order whenever a filtered list contains unknown
dates; priority sorting remains local. The legacy non-null `dateTime` fallback
is retained for compatibility, not presented as an actual event timestamp here.
The existing unknown-status fallback remains unchanged.

Refresh keeps successful rows on failure. A changed range clears old rows so they
are not mislabeled as belonging to the new range. Initial loading uses the shared
skeleton, errors allow retry, and empty API responses differ from no local matches.
Card navigation passes the mapped `CapIncident` with its numeric `incidentId`.
The second incidents screen was not changed.
