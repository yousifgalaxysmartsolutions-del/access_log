# PROJECT_UNDERSTANDING.md

Onboarding and context document for `access_log_plus` ("Access Log+").

This file is a **read-only map of the project as it exists right now**. It documents what
the code actually does, not what it is intended to do. Where documentation and code
disagree, this document follows the code and flags the disagreement explicitly.

It was produced by reading the source tree. Nothing in the project was modified to create
it. Anything that could not be confirmed from the codebase is tagged
**`Needs Verification`**.

---

## 1. Project overview and purpose

| Item | Value |
|---|---|
| Dart/Flutter package name | `access_log_plus` (`pubspec.yaml:1`) |
| Display name | `Access Log+` (`lib/app.dart:61`), iOS display name "Access Log Plus" |
| Domain | Orange Egypt / **CAP** (field-engineering "Access Log" tower maintenance app) |
| Purpose | Mobile workspace for field engineers: CAP incident management, intervention flows, evidence capture, request lifecycle, reporting, tower map, AI assistant |
| UI framework | Flutter, Material 3, `ColorScheme.fromSeed` |
| Localization | Bilingual English / Arabic, RTL-first (default locale is `ar`) |
| Design system | Orange brand `#FF7900` (`lib/core/theme/app_tokens.dart`) |
| Dart SDK | `^3.11.5` (`pubspec.yaml:22`) |
| State of maturity | **Prototype.** The vast majority of screens are driven by an in-memory mock dataset. Only authentication and the AI Copilot touch the network |

The app is a design/prototype build for an enterprise back-office + field-ops product. The
"real" backend is a test CAP server; there is no production backend integrated.

### Product surface (from screens)

Five functional areas plus two demo entries:

1. **Dashboard** — greeting, today's assignment, KPI counters, compact incident tiles.
2. **Incidents** — list with search/filter, details, multi-step action flows (assign, accept,
   reject, field task wizard), active-intervention view with elapsed timer.
3. **Requests** — request creation (intervention / renewal / departure) and "My Requests" with
   questionnaire summaries, attachments, timeline.
4. **Reporting** — reporting hub plus six report types with KPI cards and custom painters.
5. **Map** — tower sites via `flutter_map` + OpenStreetMap tiles.
6. **More** — notifications, messages, profile, language switch, device, about, logout.
7. **Design-system showcase** — visual gallery of every primitive widget.
8. **Prototype demo** — hidden scenario picker that drives all flows into specific states.

---

## 2. Folder structure

```
access_log_plus/
├── lib/
│   ├── main.dart                      9 lines   bootstrap only
│   ├── app.dart                       70        MaterialApp + session listener + theme/locale state
│   ├── models/
│   │   └── models.dart                376       all domain models + enums + copyWith helpers
│   ├── mock/
│   │   └── mock_data.dart             870       the entire prototype dataset (static consts)
│   ├── screens/                       15 files  ~12.4k lines, all prototype UI
│   ├── widgets/                       20 files  ~4.3k lines, reusable primitives
│   ├── ai_copilot/                    7 files   legacy AI layer (still the orchestrator)
│   ├── core/                          ~15 files foundation: config, di, error, network, session, storage,
│   │                                            routes, theme, localization
│   └── features/                      2 features
│       ├── authentication/            clean-architecture auth (api, models, repository, usecase, bloc)
│       └── copilot/                   Retrofit/Dio transport + Result wrapper + usecase
├── test/                              11 files  64 tests (40 widget, 24 unit)
├── android/                           Gradle Kotlin DSL, debug-only network security config
├── ios/                               Runner target, deployment target 13.0, no entitlements
├── pubspec.yaml / pubspec.lock
├── README.md                          default Flutter boilerplate, unused
├── ARCHITECTURE.md                    prior handoff doc — partly stale, see section 20
└── PROJECT_UNDERSTANDING.md           this file
```

### Exact `lib/` inventory with roles

| Path | Role | Data source |
|---|---|---|
| `lib/screens/app_shell.dart` | Root `Scaffold`, 4-tab `IndexedStack`, notched `BottomAppBar` | theme constants |
| `lib/screens/auth/auth_screens.dart` | Login + forgot-password + OTP + new-password + password-changed | **real network** (or demo) |
| `lib/screens/dashboard/cap_dashboard_screen.dart` | Home dashboard | mock |
| `lib/screens/incidents/incident_list_screen.dart` | CAP incident list + `IncidentFilterSheet` | mock |
| `lib/screens/incidents/incident_details_screen.dart` | Incident detail (largest incident file) | mock |
| `lib/screens/incidents/incident_action_flows.dart` | Assign / Accept / Reject / FieldTaskWizard | mock |
| `lib/screens/incidents/active_intervention_screen.dart` | Live intervention + elapsed timer | mock |
| `lib/screens/incidents/new_request_flows.dart` | Request chooser + `NewRequestWizard` | mock |
| `lib/screens/requests/my_requests_screen.dart` | My Requests list + `RequestDetailsScreen` | mock |
| `lib/screens/reporting/reporting_screen.dart` | Reporting hub + 6 reports, custom painters | mock |
| `lib/screens/map/tower_map_screen.dart` | `flutter_map` tower map | mock sites + **real OSM tiles** |
| `lib/screens/more/more_screens.dart` | Notifications, messages, profile, language, device, about, MoreHub, logout | mock |
| `lib/screens/component_showcase/component_showcase_screen.dart` | Design-system gallery | mock |
| `lib/screens/component_showcase/prototype_demo_screen.dart` | Hidden scenario picker | mock |
| `lib/widgets/*.dart` (20) | Design-system primitives + complex mock widgets | n/a |

### Notable widget files

`app_button.dart`, `app_text_field.dart`, `section_card.dart`, `info_row.dart`,
`status_chip.dart`, `step_indicator.dart`, `timeline_item.dart`, `empty_state.dart`,
`action_card.dart`, `incident_card.dart`, `cap_incident_card.dart`, `attachment_card.dart`,
`questionnaire_field.dart`, `action_flow_components.dart`, `dynamic_questionnaire.dart`
(837 lines, conditional-field engine), `evidence_collection.dart` (811 lines,
`PhotoCaptureScreen` / `SignaturePadView` / `MockPhotoPicker`), `location_validation.dart`
(523 lines, 5 mock GPS outcomes), `identity_verification_mock.dart`,
`background_simulation_components.dart` (734 lines), `session_timeout_ui.dart`.

---

## 3. Main architecture and layers

The project runs **three architectural generations side by side**. This is the single most
important thing to understand before touching anything.

```
Layer A  Prototype UI          lib/screens/, lib/widgets/, lib/mock/, lib/models/
        (old, ~16.7k lines)    widget-level, direct references to MockData statics,
                                no repository/use-case abstraction, no BLoC

Layer B  Foundation            lib/core/**            NEW, untracked in git
        (new, ~1.7k lines)     config, DI, error, network, session, storage

Layer C  Features              lib/features/**        NEW, untracked in git
        (new, ~0.3k lines)     authentication/ + copilot/
                                clean architecture intent:
                                presentation -> domain -> data

Layer A' Legacy AI             lib/ai_copilot/**      pre-dates B/C, still load-bearing
        (1.3k lines)           orchestrator + prompts + models live here
```

### Dependency direction (important — it is not clean)

```
lib/core/di/injection.dart  ──imports──>  lib/ai_copilot/**   (Layers B and C depend on A')
lib/features/copilot/data/* ──imports──>  lib/ai_copilot/**
lib/features/authentication/domain/repositories/auth_repository.dart
                                   ──imports──>  lib/features/authentication/data/models/auth_models.dart
                                   (domain importing data — inward dependency violation)
```

So the "new architecture" is layered, but the arrows point in both directions: `core` and
`features` depend on legacy root folders, and the auth domain interface imports from its own
`data` layer. Treat `lib/features/*` and `lib/ai_copilot` as one coupled unit.

### Boot sequence

`lib/main.dart:5-9` — the entire bootstrap:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();     // awaited BEFORE runApp
  runApp(const AccessLogApp());
}
```

Implications:

- `configureDependencies()` throwing (see `StateError` in section 12) crashes **before any
  Flutter UI exists**, so the user sees a black screen / native crash, never an error widget.
- `AccessLogAppState.initState` (`lib/app.dart:23`) guards its `SessionManager` subscription
  with `services.isRegistered<SessionManager>()`. Since DI is awaited first, that guard is
  always true in the real app; it exists so widget tests can pump `AccessLogApp` without DI.
- `initialRoute` (`lib/app.dart:55-59`) is computed at first build from
  `SessionManager.isAuthenticated`. Because `restore()` is awaited inside DI, cold-start
  routing is correct.

---

## 4. Legacy vs new architecture

### What the old architecture looked like

`lib/screens/**` and `lib/widgets/**` are classic prototype code:

- Screens read `MockData.<collection>` statics directly (`lib/mock/mock_data.dart`).
- State lives in `StatefulWidget` `State` fields.
- No repository, no use case, no abstraction over data.
- The only network code in the legacy half is `IoAiHttpTransport` in `lib/ai_copilot/`.
- Ad-hoc localization: a small `AppStrings` map plus inline `context.tr(english, arabic)`
  pairs, plus a second pass (`MockContentLocalization`) that translates mock dataset strings.

### What the new architecture added

| Concern | Legacy location | New location | Status |
|---|---|---|---|
| Config / env | none | `lib/core/config/environment.dart` | new |
| DI container | none | `lib/core/di/injection.dart` (`GetIt.instance`) | new |
| HTTP client | `IoAiHttpTransport` (dart:io) | `DioClient` + `SafeLoggingInterceptor` + `AuthInterceptor` | new |
| Error model | ad-hoc strings | sealed `Failure` hierarchy + `Result<T>` + `ExceptionMapper` + `apiGuard` | new |
| Token storage | none | `SecureStorageService` (`flutter_secure_storage`) | new |
| Session state | `MockData.sessionTimeoutMinutes` constants + `Timer.periodic` | `SessionManager` | new |
| Auth UI→network | none (mock login only) | `LoginBloc` → `LoginUseCase` → `AuthRepository` → `AuthApiService` | new |
| AI transport | `IoAiHttpTransport` | `RetrofitAiTransport` + `CopilotApiService` | new (old one now dead) |
| AI orchestration | `AiCopilotService` | **still `AiCopilotService`** | not migrated |
| AI models/prompts | `ai_copilot_models.dart`, `ai_copilot_prompts.dart` | **still legacy** | not migrated |
| AI state | `AiCopilotController` (Cubit) | **still legacy** | not migrated |
| Routing | none | `lib/core/routes/app_routes.dart` | new |
| Theme / tokens | none | `lib/core/theme/*` | pre-existing, tracked |

### Migration philosophy actually applied

The new layer **wraps** the legacy layer rather than replacing it. `CopilotRepository` takes
an `AiCopilotClient` (a legacy interface) and adapts its failures into `Result<String>`. The
screen and controller stay where they are. Same for auth: the new repository interface is
implemented by both a real and a demo class, selected once at DI time.

`ARCHITECTURE.md:150-153` lists which existing files were modified:

```
pubspec.yaml/lock, main.dart, app.dart, core/routes/app_routes.dart,
screens/auth/auth_screens.dart, widgets/session_timeout_ui.dart,
and the Copilot service/controller/screen.
```

---

## 5. Main features and modules

| Feature | Entry point | Network? | Backend |
|---|---|---|---|
| Authentication | `LoginScreen` (`lib/screens/auth/auth_screens.dart`) | **Yes** | CAP `/CAP/CapAuth/Login` |
| Session refresh | `AuthInterceptor` | **Yes** | CAP `/CAP/CapAuth/RefreshToken` (see section 20) |
| Password recovery | `ForgotPasswordScreen`, `OtpVerificationScreen`, `CreateNewPasswordScreen` | No | prototype only |
| AI Copilot | `AiCopilotScreen` | **Yes** | Groq OpenAI-compatible API |
| Incidents (list/details/actions/intervention) | `IncidentListScreen` etc. | No | mock |
| Requests (create/my requests) | `NewRequestWizard`, `MyRequestsScreen` | No | mock |
| Reporting | `ReportingScreen` | No | mock |
| Tower map | `TowerMapScreen` | Partial — real OSM raster tiles (`lib/screens/map/tower_map_screen.dart:141`), mock sites | `tile.openstreetmap.org` |
| Notifications / profile / more | `MoreHubScreen` | No | mock |
| Location validation | `location_validation.dart` | No | 5 simulated outcomes |
| Evidence capture | `evidence_collection.dart` | No | mock photo picker + signature pad |
| Identity verification | `identity_verification_mock.dart` | No | periodic re-verify simulation |
| Design-system showcase | `ComponentShowcaseScreen` | No | — |
| Prototype scenario runner | `PrototypeDemoScreen` (hidden) | No | drives all flows |

### Navigation

`AppShell` (`lib/screens/app_shell.dart:26-31`) is a `Scaffold` with an `IndexedStack` over
**four** destinations: `CapDashboardScreen`, `IncidentListScreen`, `MyRequestsScreen`,
`MoreHubScreen` — rendered as a notched `BottomAppBar` with a center gap (`app_shell.dart:140-172`).
The map screen is *not* a shell tab; it is reached from the More hub.

Long-pressing the "+" logo in the app bar navigates to `AppRoutes.prototypeDemo`
(`app_shell.dart:38`) — the hidden prototype entry point.

Note: incidents exist both as shell tab index 1 and as the named route
`AppRoutes.incidentList`. `cap_dashboard_screen.dart` pushes the named route, so there are two
independent `IncidentListScreen` instances (with separate `State`) depending on entry path.

---

## 6. API and networking flow

### Endpoints actually defined

`lib/core/network/api_endpoints.dart` — only two:

```dart
static const login   = '/CAP/CapAuth/Login';
static const refresh = '/CAP/CapAuth/RefreshToken';
```

Plus one unused template path, `'/attachments'` (`lib/core/network/upload_api_service.dart:11`).

### Base URL composition

`AppEnvironment.apiUrl` (`lib/core/config/environment.dart:16-17`):

```dart
'${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/${apiVersion.isEmpty ? '' : '$apiVersion/'}'
```

It strips trailing slashes from `baseUrl` and **always** appends one `/`. With the default
base URL and empty `API_VERSION` this yields
`https://test.talentlink360.com/Developmnet/BridgeForce_Dev/BridgeFoce_API_Dev/api/`.

Retrofit endpoints are absolute (`/CAP/CapAuth/Login`), so the naive concatenation produces a
double slash (`.../api//CAP/CapAuth/Login`). Dio's `RequestOptions.uri` normalization
collapses it, so the effective request URL matches `ARCHITECTURE.md:31`. The behavior is
correct but it depends on undocumented Dio path normalization.

**`Needs Verification`** — this was reasoned from Dio's documented URL composition, not
observed in a network capture. The effective URL is consistent with the doc, but the
double-slash intermediate is a latent fragility.

### Request/response wrapper

`ApiResponse` (`lib/core/network/api_response.dart`) is a thin newtype over
`Map<String, dynamic>`. `fromJson` is identity and `toJson()` returns the **same map
reference**, not a copy. Its doc comment ("Unwrap according to each endpoint contract, not by
guessing envelope keys") is a policy note; there is no envelope parsing in this class. All
actual CAP envelope parsing lives in `CapLoginResponse.parse`.

### Error model

`sealed class Failure` (`lib/core/error/failure.dart:1`) with `final String message` and a
default English message per subclass:

`NetworkFailure`, `UnauthorizedFailure`, `ServerFailure`, `ValidationFailure`,
`TimeoutFailure`, `CancelledFailure`, `UnknownFailure`, and `ServiceFailure(code)` (the only
one carrying extra structure).

No subclass overrides `toString()`, so a `Failure` in a log prints as
`Instance of 'UnauthorizedFailure'`. The `message` field is effectively write-only because
the UI never surfaces it — see section 8.

`sealed class Result<T>` (`lib/core/network/result.dart`) with `Success<T>(data)` and
`FailureResult<T>(failure)`. Minimal; no `map`/`fold`/`isSuccess` helpers.

`ApiException` (`lib/core/network/api_exception.dart`) wraps a `Failure` and implements
`Exception` — the bridge from domain errors back into the transport layer.

`ExceptionMapper.map(Object)` (`lib/core/error/exception_mapper.dart:7-27`) mapping table:

| Input | Result |
|---|---|
| `ApiException` | its `failure` |
| `DioException` with `error.error is Failure` | that failure (passthrough) |
| `DioExceptionType.cancel` | `CancelledFailure` |
| `connectionTimeout` / `sendTimeout` / `receiveTimeout` | `TimeoutFailure` |
| `connectionError` / `badCertificate` | `NetworkFailure` |
| status 401 or 403 | `UnauthorizedFailure` |
| status 400 or 422 | `ValidationFailure` |
| status >= 500 | `ServerFailure` |
| any other status (incl. 3xx, 404, 409) | `UnknownFailure` |
| anything else | `UnknownFailure` |

`apiGuard<T>(operation)` (`exception_mapper.dart:31-37`) is the intended error boundary:

```dart
Future<Result<T>> apiGuard<T>(Future<T> Function() operation) async {
  try {
    return Success(await operation());
  } on Exception catch (error) {
    return FailureResult(ExceptionMapper.map(error));
  }
}
```

Two caveats:
1. It catches `on Exception` only — **not** `Error`/`TypeError`. `StateError` from
   `AppEnvironment.fromDefines()` and `ArgumentError` from `Environment.values.byName` both
   escape it.
2. It is used in exactly **one** place: `AuthRepositoryImpl.login`
   (`lib/features/authentication/data/repositories/auth_repository_impl.dart:21`).
   `CopilotRepository.complete` (`lib/features/copilot/data/copilot_repository.dart:14-23`)
   hand-rolls its own try/catch, so the doc comment "Single error boundary shared by
   repositories" is aspirational.

---

## 7. Dio instances and their responsibilities

Three separate `Dio` objects, all built by `DioClient.create`
(`lib/core/network/dio_client.dart:18-42`).

| # | Registered as | Base URL | Interceptors | Purpose |
|---|---|---|---|---|
| 1 | default singleton (`injection.dart:73`) | `config.apiUrl` (CAP) | `SafeLoggingInterceptor` → `AuthInterceptor` | all CAP backend calls |
| 2 | `instanceName: 'refresh'` (`injection.dart:42-46`) | `config.apiUrl` (CAP) | `SafeLoggingInterceptor` only | token refresh only — **no `AuthInterceptor`, so no recursion/deadlock** |
| 3 | `instanceName: 'copilot'` (`injection.dart:88-95`, lazy) | `AiProviderConfig.baseUrl` (`https://api.groq.com/openai/v1`) | `SafeLoggingInterceptor` only | AI provider — **no `AuthInterceptor`, so the provider key never enters the app refresh flow** |

### Shared `BaseOptions` (`dio_client.dart:20-28`)

- `connectTimeout: 15s`, `receiveTimeout: 30s`, `sendTimeout: 30s`
- `contentType: Headers.jsonContentType`, `headers: {'Accept': 'application/json'}`
- `followRedirects: false` — any 3xx falls through Dio's default `validateStatus` (2xx only)
  into `ExceptionMapper`, which has **no 3xx arm**, so 3xx becomes `UnknownFailure`.

No `QueuedInterceptor`, no `RetryInterceptor`, no `validateStatus` override.

### Interceptor ordering (matters)

Dio chains interceptors **FIFO in registration order** for all three phases. In
`injection.dart`, `SafeLoggingInterceptor` is added inside `DioClient.create` (line 36) and
`AuthInterceptor` is added afterward (line 47). Consequences:

- `onRequest`: logging runs **before** auth attaches the header, so logged request headers do
  **not** contain `Authorization`. (Helpful by accident.)
- `onError`: logging runs **before** auth, so the raw 401 is logged before the refresh attempt.
- `onResponse`: when `AuthInterceptor` resolves a retry via `handler.resolve(...)`, the outer
  chain's logging interceptor also runs, so retried requests produce **duplicate RESPONSE
  log lines**. This follows from Dio's `resolve` semantics; it was not observed at runtime.

### `SafeLoggingInterceptor` (`lib/core/network/interceptors/logging_interceptor.dart`)

Registered only when `logging == true`, and `logging` is already
`kDebugMode && API_LOGGING` (`environment.dart:41-43`). It double-guards with
`if (!kDebugMode) return;`. **Release builds never attach it and never log.**

Redaction (`redact(value, key, depth)`, lines 12-56):

- Sensitive key regex (lines 9-12): `password|passwd|pwd|token|authorization|cookie|secret|apikey|api_key|credential`, case-insensitive substring match on the key. Covers `AccessToken`, `RefreshToken`, `devicetoken`. Does **not** cover `sessionId`, `userid`, `ipaddress`.
- Depth cap 12 → `'[nested content omitted]'`.
- `FormData` → `{fields: [...], files: [{field, bytes}]}` — **file contents are never logged**, only byte counts.
- `List` → `.take(100)` (items beyond 100 are silently dropped).
- `String` → tries `jsonDecode`; if it yields Map/List, redacts structurally; otherwise sniffs for `Bearer\s` or the JWT shape `eyJ[A-Za-z0-9_-]+\.` → `'[sensitive text omitted]'`. Strings > 2000 chars truncated.
- `null`/`num`/`bool` pass through; any other type → `'[<Type> omitted]'`.
- Post-serialization scrub pass (lines 90-108) replaces the JSON-escaped value of every sensitive key everywhere it appears in the output.

Log URL is **rebuilt from parts only** (`scheme`, `host`, `port`, `path`) so user-info and the
raw query string never reach the log; the query is logged separately through
`redact(request.queryParameters)`. Three stages: `REQUEST`, `RESPONSE`, `ERROR`. Output hard
capped at 16000 chars. Timing uses an `Expando<Stopwatch>` keyed on `RequestOptions`.

### `AuthInterceptor` (`lib/core/network/interceptors/auth_interceptor.dart`) — see sections 9 and 10.

---

## 8. Authentication flow

### Full chain

```
LoginScreen._login()                      lib/screens/auth/auth_screens.dart:~287
  guards: bloc not loading;
          live mode requires non-empty user + password;
          mock mode + preview ∉ {normal, loading} blocks submit
  └─ bloc.add(LoginSubmitted(user.trim(), pass, remember))
       ↓
LoginBloc.on<LoginSubmitted>              lib/features/authentication/presentation/bloc/login_bloc.dart:22
  emit(loading) → await login(...) → emit(success | failure)
       ↓
LoginUseCase.call                         lib/features/authentication/domain/usecases/login_use_case.dart
  pure passthrough to repository
       ↓
AuthRepository (interface)                lib/features/authentication/domain/repositories/auth_repository.dart
       ↓  (implementation chosen once at DI time)
AuthRepositoryImpl.login                  lib/features/authentication/data/repositories/auth_repository_impl.dart:17-26
  apiGuard(() async {
    response = (await api.login(LoginRequest(username, password))).data
    parsed  = CapLoginResponse.parse(response, username)
    await session.signIn(parsed.tokens, remember: remember)
    return parsed.user
  })
       ↓
AuthApiService.login → _AuthApiService.login (auth_api_service.g.dart)
  @Extra({'public': true}) → Options.extra → RequestOptions.extra
       ↓
Dio (default instance) → AuthInterceptor skips (public) → HTTPS → CAP login endpoint
       ↓
SessionManager.signIn → SecureStorageService.writeTokens (key 'access_log.session.v1')
       ↓
LoginScreen stream listener sees LoginStatus.success
  → Navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false)
```

The screen consumes the bloc with a **manual `StreamSubscription`**
(`auth_screens.dart:206-266`) and a manual `_bloc?.close()` in `dispose`. `BlocProvider` /
`BlocBuilder` are never used in this project despite `flutter_bloc: ^9.1.1` being a dependency.

### CAP request envelope

`LoginRequest.toJson()` (`lib/features/authentication/data/models/auth_models.dart:12-36`) —
hand-written map, no `json_serializable`:

```json
{
  "userid": 0,
  "ipaddress":   "<CAP_DEVICE_ID,  default FUH0216913004222>",
  "devicetoken": "<CAP_DEVICE_TOKEN, default testtokens>",
  "osversion":   "<CAP_OS_VERSION,  default 15.1>",
  "AppVersion":  "<CAP_APP_VERSION, default 1>",
  "devicetype":  "<CAP_DEVICE_TYPE, default iOS>",
  "lang":        "<CAP_LANGUAGE,     default en>",
  "data": { "UserName": "<username>", "Password": "<password>" }
}
```

`RefreshTokenRequest.toJson()` (`auth_models.dart:42-65`) is the same block **minus `lang`**,
with `data: { "RefreshToken": <token> }`.

These are **compile-time test fixtures**, not detected device information — `CAP_DEVICE_TYPE`
defaults to the literal `'iOS'` even on Android. This matches `ARCHITECTURE.md:35-38`.

### CAP response parsing

`CapLoginResponse.parse(response, username)` (`lib/features/authentication/data/models/cap_login_response.dart:12-44`),
in order:

1. `response['resultcode'] != 1` → `ApiException(UnauthorizedFailure())`. Strict: a string `"1"` is rejected. (`1.0 == 1` in Dart so a double would pass.)
2. `data` not a `Map<String, dynamic>` → `FormatException('Missing CAP user data')`.
3. `data['User_MobileEnable'] == false || data['User_MobileActivationState'] == false` → `ApiException(ServiceFailure('inactive_user'))`. **Only an explicit boolean `false` rejects.**
4. Token/identity validation — `AccessToken` non-blank String, `RefreshToken` non-blank String, `User_PK_ID` **`is num`** (a string id is rejected), `User_Name` non-empty String — else `FormatException('Invalid CAP login response')`.
5. Success → `CapLoginResponse(AuthUser(id, name), SessionTokens(access, refresh))`.

A HTTP 200 alone never creates a session — the class doc comment states this explicitly
(lines 6-7) and `test/cap_login_contract_test.dart` enforces it.

### Failure → user-visible message

`_LoginScreenState` maps each failure **type** to bilingual copy
(`auth_screens.dart:225-256`) — it never surfaces `Failure.message`:

| Failure | English message shown |
|---|---|
| `NetworkFailure` | "Cannot connect to the test server. Check your connection or VPN." |
| `TimeoutFailure` | "The server did not respond in time." |
| `UnauthorizedFailure` | "Sign-in rejected. Check your username and password." |
| `ServiceFailure(code: 'inactive_user')` | "Mobile access is inactive. Contact your administrator." |
| `ServerFailure` | "The server is temporarily unavailable." |
| anything else | "Sign-in could not be completed. Check your details; the server response may need integration." |

### Mock vs live authentication

Selection is a **one-time branch inside `configureDependencies`** (`injection.dart:77-81`):

```dart
registerLazySingleton<AuthRepository>(() => config.mockAuthentication
    ? DemoAuthRepository(session)
    : AuthRepositoryImpl(services<AuthApiService>(), session));
```

There is **no runtime toggle** — changing mode requires a rebuild with a different
`--dart-define`.

`DemoAuthRepository` (`auth_repository_impl.dart:47-63`) ignores both credentials, calls
`session.startDemo()`, and returns a hardcoded `AuthUser(id: 'demo-engineer', name: 'Ahmed Mohamed')`.

Behavioral differences between modes:

| Behavior | live (`MOCK_AUTH=false`, the default) | mock (`MOCK_AUTH=true`) |
|---|---|---|
| `session.restore()` at boot | yes | **skipped** |
| route guard in `app_routes.dart:25-39` | enforced | **skipped** — any route reachable |
| empty-credential validation | enforced | skipped |
| biometric button | shows "sign in with password" snackbar | performs login |
| login preview states | cosmetic, do not block | `invalid`/`inactive`/`unauthorized` block login |

### Biometrics

`ARCHITECTURE.md:82-83` claims the biometric button cannot bypass password authentication in
live mode. The code matches: in live mode the button shows a snackbar telling the user to
sign in with a password. There is no `local_auth` dependency — no real biometric capture.

### Prototype preview selector leak

`_PreviewSelector` is rendered unconditionally in the login screen, including live mode.
Setting `invalid` displays "Incorrect password" field errors and a red banner **before any
attempt**, while still allowing login to proceed. This is prototype affordance visible in a
live build.

---

## 9. Refresh token flow

### On-request path (`AuthInterceptor.onRequest`, lines 19-46)

1. If `request.extra['public'] == true` → pass through untouched (line 24-27). This is how
   Retrofit `@Extra({'public': true})` on `AuthApiService.login`/`refresh` works.
2. **Cross-origin guard** (line 29): `options.uri.origin != Uri.parse(dio.options.baseUrl).origin`
   → reject. This prevents the session token from being attached to a redirect or absolute URL
   on another host. Origin-level only — path is not checked.
3. `await _refreshing` (line 32) — every protected request blocks behind any in-flight refresh.
4. Require `session.isAuthenticated && session.tokens != null`, else reject (lines 33-35).
5. Reject if the request was already cancelled (lines 36-38).
6. Attach `Authorization: Bearer <accessToken>` and stamp
   `extra['sessionGeneration'] = session.generation` (lines 39-41).
7. Any thrown non-`DioException` is converted to `_expired` (lines 43-45).

`_protected(request)` is simply `request.extra['public'] != true` (line 12) — i.e. **opt-out**,
so forgetting `@Extra` makes an endpoint protected.

`_expired(request)` (lines 13-17) synthesizes a `DioException` with
`error: const UnauthorizedFailure()`. Because `ExceptionMapper` checks `error.error is Failure`
*before* the status switch, this maps to `UnauthorizedFailure` rather than `UnknownFailure`.

### Refresh call (`AuthInterceptor._rotate`, lines 48-58)

```dart
Future<void> _rotate(int epoch) async {
  try {
    final token = session.tokens?.refreshToken;
    if (token == null) throw const FormatException('No refresh token');
    final value = await refresh(token);
    await session.rotate(value, epoch);
  } catch (_) {
    if (epoch == session.generation) await session.logout(expired: true);
    rethrow;
  }
}
```

The `refresh` callback is **injected by DI** (`injection.dart:51-70`), not owned by the
repository. In mock mode it returns `const SessionTokens('demo-access', 'demo-refresh')`.
In live mode it calls `AuthApiService(refreshDio).refresh(...)` and inlines the CAP parsing:

```dart
if (response['resultcode'] != 1) throw const FormatException('Refresh token failed');
if (data is! Map<String, dynamic>) throw const FormatException('Missing CAP refresh data');
// both tokens must be non-empty Strings
```

On **any** failure, if the epoch is still current, the session is logged out with
`expired: true` and the error is rethrown.

### On-error path (`AuthInterceptor.onError`, lines 60-111)

Bails immediately via `handler.next(error)` unless **all** of:
- the request is protected, **and**
- `error.response?.statusCode == 401`, **and**
- `request.extra['authRetried'] != true` (the loop breaker).

Then:

1. Read `epoch = request.extra['sessionGeneration']`. If not authenticated or the epoch moved
   → reject with `_expired` (stale-401 protection, lines 70-74).
2. **Conditional single-flight refresh** (lines 76-84): only refresh if the failing request's
   `Authorization` header equals `Bearer ${session.tokens?.accessToken}`, i.e. the failing
   token is still the current one. Then:
   ```dart
   final running = _refreshing ??= _rotate(session.generation);
   try { await running; } finally {
     if (identical(_refreshing, running)) _refreshing = null;
   }
   ```
   The `identical` guard prevents a late-completing first refresh from nulling a second one.
3. Re-verify authentication and epoch (lines 85-87).
4. Re-check cancellation (lines 88-90).
5. **Streams are never replayed** — `if (request.data is Stream) { handler.next(error); return; }` (lines 92-95), with the comment "callers should use FormData or repeatable bytes".
6. **`FormData` is `.clone()`d** before retry; other body types pass through (lines 96-98).
7. Retry exactly once via `request.copyWith(data, extra: {...extra, 'authRetried': true}, headers: {..., Authorization: Bearer <new token>})` then `handler.resolve(await dio.fetch<dynamic>(retry))` (lines 99-107).

### Recursion prevention

The refresh call goes out on the separate `'refresh'` Dio instance, which has **no**
`AuthInterceptor`. So a 401 from refresh cannot trigger another refresh. `injection.dart:37`
documents this explicitly.

### What happens on refresh failure

`_rotate` calls `session.logout(expired: true)` → `SessionManager.status` becomes `expired`
and a change event is emitted → `AccessLogAppState`'s listener (`app.dart:27-32`) sees a
non-`authenticated` status and does
`pushNamedAndRemoveUntil(AppRoutes.login, (_) => false)`, clearing the whole stack.

Because the interceptor's synthesized failures are all `UnauthorizedFailure`, and the login
screen renders `UnauthorizedFailure` as "Sign-in rejected. Check your username and password."
(`auth_screens.dart:236-240`), **a refresh failure at the login screen is
indistinguishable from a wrong password.**

---

## 10. Session management

`SessionManager` — `lib/core/session/session_manager.dart` (71 lines). Registered as an eager
singleton with `dispose` (`injection.dart:32-35`).

### State

```dart
enum SessionStatus { signedOut, authenticated, expired }   // line 4
SessionStatus status = SessionStatus.signedOut;             // public, mutable
SessionTokens? tokens;                                     // public, mutable
int generation = 0;                                        // public, mutable epoch
bool _remember = true;
Future<void> _writes = Future.value();
```

`status`, `tokens` and `generation` are **public mutable fields with no encapsulation** — any
holder of a `SessionManager` can set `session.status` directly and bypass every guard.

### Serialized writes

```dart
Future<void> _serialize(Future<void> Function() action) {
  final next = _writes.then((_) => action());
  _writes = next.catchError((Object _) {});   // a failed write doesn't poison the chain
  return next;                                // but the error still reaches the caller
}
```

All storage mutations chain through this, so they execute strictly in order.

### Methods

| Method | Lines | Behavior |
|---|---|---|
| `restore()` | 24-29 | Reads storage; sets status. **Does not go through `_serialize` and does not emit.** Awaited in DI before `runApp`. |
| `signIn(value, {remember})` | 31-41 | `++generation`; set `_remember`; persist (`writeTokens`) or **clear** storage when `remember == false`; re-check epoch; assign tokens + `authenticated`; emit. |
| `rotate(value, epoch) -> bool` | 43-53 | Returns `false` if epoch stale or not authenticated. Writes to storage only when `epoch == generation && isAuthenticated && _remember`. Re-checks, assigns, returns `true`. |
| `startDemo()` | 55-60 | `++generation`; `tokens = null`; `status = authenticated`; emit. Touches neither storage nor `_remember`. |
| `logout({expired})` | 62-68 | `++generation`; null tokens; set status; **emit immediately**; then `await _serialize(storage.clear)`. |
| `dispose()` | 70 | Closes the broadcast `StreamController`. |

### Generation counter

`generation` is the concurrency epoch shared with `AuthInterceptor`. It is bumped by
`signIn`, `startDemo` and `logout`. `AuthInterceptor` stamps it into
`extra['sessionGeneration']` on every protected request and re-checks it in three places
(`onRequest` after refresh wait, `onError` before refresh, `onError` after refresh). A late
refresh result therefore cannot resurrect a session after logout.

### Expiry — there is none

`SessionManager` has **no timer, no JWT `exp` parsing, no clock-skew allowance, no idle
timeout**. Expiry is purely reactive: a 401 on a protected request triggers `_rotate`; a
failed `_rotate` triggers `logout(expired: true)`.

`SessionStatus.expired` is dead as a UI concept — `app.dart:27` only tests
`!= authenticated` and `app_routes.dart:27` only tests `isAuthenticated`, so expired and
signed-out are indistinguishable to the user.

The session-timeout UI (`lib/widgets/session_timeout_ui.dart`) is a **prototype simulation**
driven by `MockData.sessionTimeoutMinutes = 30` / `sessionWarningSeconds = 60`. It is not
wired to `SessionManager`; "Stay Logged In" only cancels a `Timer.periodic`. The only real
integration is the dialog buttons calling `navigateToSecureLogin`.

`navigateToSecureLogin` (`session_timeout_ui.dart:13-23`) has two behaviors:

```dart
void navigateToSecureLogin(BuildContext context) {
  if (services.isRegistered<SessionManager>()) {
    unawaited(services<SessionManager>().logout());   // navigation is delegated to app.dart
    return;
  }
  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
}
```

The first branch is the app path; the second is what non-DI'd widget tests exercise.

### Logout flow end to end

`more_screens.dart` `_logout` → `showActiveInterventionLogoutWarning` confirm dialog →
`navigateToSecureLogin` → `unawaited(SessionManager.logout())` → `_changes.add(signedOut)` →
`AccessLogAppState` listener → `pushNamedAndRemoveUntil(AppRoutes.login, (_) => false)`.
Stack is cleared; the back button cannot return into authenticated screens.
`test/session_timeout_test.dart` asserts `handlePopRoute()` returns `false`.

Because the navigation is indirect and un-awaited and `navigateToSecureLogin` is reachable
from several dialogs, a double tap can push the login route twice. The end state is the
same screen either way, but it is not deduplicated.

### Token storage

`SecureStorageService` (`lib/core/storage/secure_storage_service.dart`), backed by
`flutter_secure_storage` `^11.2.0`, single key `'access_log.session.v1'`.

- **Both tokens share one record** so a rotation cannot leave a mixed pair (line 47 comment).
- `readTokens` catches `FormatException` and `TypeError`, clears storage, returns `null`.
- `SessionTokens.fromJson` treats a missing `refreshToken` as `''`, not an error (line 9) —
  and `AuthInterceptor._rotate` only null-checks, so it can fire a refresh request with an
  **empty** refresh token.
- No `IOSOptions` / `AndroidOptions` are configured.

---

## 11. Dependency injection

`lib/core/di/injection.dart` uses the **global `GetIt.instance`**:

```dart
final services = GetIt.instance;   // line 21
```

`app.dart`, `app_routes.dart`, `auth_screens.dart`, `session_timeout_ui.dart` and
`ai_copilot_screen.dart` all import `services` directly. This is a service-locator read at
call sites, not constructor injection.

`configureDependencies({AppEnvironment? environment, TokenStorage? storage})` is **idempotent**
via an early return on `services.isRegistered<SessionManager>()` (line 26). The `environment`
and `storage` parameters exist purely as test seams.

### Full registration table

| Type | Style | Lines | Notes |
|---|---|---|---|
| `AppEnvironment` | `registerSingleton` | 28 | `environment ?? AppEnvironment.fromDefines()` |
| `TokenStorage` | `registerSingleton` | 29 | `storage ?? SecureStorageService()` |
| `SessionManager` | `registerSingleton` + `dispose` | 30-35 | built eagerly so `restore()` can be awaited at line 31 (skipped in mock mode) |
| `Dio` `'refresh'` | `registerSingleton` + `dispose` | 38-46 | no `AuthInterceptor` |
| `Dio` (default) | `registerSingleton` + `dispose` | 47-73 | `AuthInterceptor` added at 47 before registration |
| `AuthApiService` | `registerLazySingleton` | 74-76 | over the default Dio |
| `AuthRepository` | `registerLazySingleton` | 77-81 | **conditional**: `DemoAuthRepository` vs `AuthRepositoryImpl` |
| `LoginUseCase` | `registerLazySingleton` | 82-84 | |
| `LoginBloc` | **`registerFactory`** | 85-87 | per-screen instance |
| `Dio` `'copilot'` | `registerLazySingleton` + `dispose` | 88-95 | Groq base URL, no `AuthInterceptor` |
| `CopilotApiService` | `registerLazySingleton` | 96-98 | |
| `AiCopilotClient` | `registerLazySingleton` | 99-103 | `AiCopilotService.fromEnvironment(transport: RetrofitAiTransport(...))` |
| `CopilotRepository` | `registerLazySingleton` | 104-106 | |
| `CompleteCopilotUseCase` | `registerLazySingleton` | 107-109 | |

This matches `ARCHITECTURE.md:133` ("Register service/repository/use case lazily and Bloc as a
factory") exactly.

### DI observations

- The refresh closure is built **inside DI** (`injection.dart:51-70`), not inside a
  repository. It duplicates `AuthRepositoryImpl.refresh` almost line-for-line. See section 19.
- In mock mode the `AuthInterceptor` is **still attached** to the shared Dio even though
  `DemoAuthRepository` never uses it and `SessionManager.tokens` is `null` while status is
  `authenticated`. Any protected call in mock mode would be rejected. Latent — currently
  unreachable.
- In mock mode `configureDependencies` skips `session.restore()` **and never clears secure
  storage**. Tokens written by an earlier real-login run persist on disk through a whole
  mock-auth session and are picked up by the next non-mock launch.
- Nothing ever calls `GetIt.reset()` or unregisters in the app.

---

## 12. Environment and configuration

`lib/core/config/environment.dart`. **All configuration is compile-time
`String.fromEnvironment` / `bool.fromEnvironment`.** There is no `.env` file, no flavors, no
build_config package.

```dart
enum Environment { development, staging, production }   // line 3

class AppEnvironment {
  const AppEnvironment({
    required this.environment,
    required this.baseUrl,
    this.apiVersion = 'v1',           // line 9
    this.mockAuthentication = true,   // line 10
    this.logging = false,
  });
```

### Every define

| Define | Default | Read at | Effect |
|---|---|---|---|
| `APP_ENV` | `'development'` | `environment.dart:20` | `Environment.values.byName(...)` |
| `MOCK_AUTH` | `false` | `environment.dart:22` | `false` = **live CAP login is the default** |
| `API_BASE_URL` | `https://test.talentlink360.com/Developmnet/BridgeForce_Dev/BridgeFoce_API_Dev/api` | `environment.dart:23-27` | CAP host |
| `API_VERSION` | `''` | `environment.dart:39` | empty ⇒ no version segment |
| `API_LOGGING` | `true` | `environment.dart:43` | ANDed with `kDebugMode` |
| `CAP_ALLOW_INVALID_CERTIFICATE` | **`true`** | `dio_client.dart:9-12` | scoped TLS bypass — see section 18 |
| `CAP_DEVICE_ID` | `'FUH0216913004222'` | `auth_models.dart:14-17` and again at 44-47 | sent as `ipaddress` |
| `CAP_DEVICE_TOKEN` | `'testtokens'` | `auth_models.dart:18-21` / 48-51 | sent as `devicetoken` |
| `CAP_OS_VERSION` | `'15.1'` | `auth_models.dart:22-25` / 52-55 | sent as `osversion` |
| `CAP_APP_VERSION` | `'1'` | `auth_models.dart:26-29` / 56-59 | sent as `AppVersion` |
| `CAP_DEVICE_TYPE` | `'iOS'` | `auth_models.dart:30-33` / 60-63 | **hardcoded string, not detected** |
| `CAP_LANGUAGE` | `'en'` | `auth_models.dart:34` | `LoginRequest` only; absent from `RefreshTokenRequest` |
| `GROQ_API_KEY` | `''` | `ai_provider_config.dart:5-8` | empty ⇒ AI mock mode |
| `GROQ_MODEL` | `'qwen/qwen3.6-27b'` | `ai_provider_config.dart:9-12` | see section 21 |
| *(hardcoded)* | `'llama-3.1-8b-instant'` | `ai_provider_config.dart:13` | AI fallback model |

### Validation (`environment.dart:28-35`)

In **non-mock** mode it throws `StateError` if the URL has no authority, or if
`environment != development` and the URL is not HTTPS. The error message is:
`"A valid API_BASE_URL is required. Staging/production require HTTPS."`

### Configuration inconsistencies

1. **`apiVersion` default mismatch.** Constructor default `'v1'` (line 9) vs
   `fromDefines()` explicit `''` (line 39). The constructor default is unreachable from the
   app and misleading — direct construction would produce a `/v1/` segment.
2. **`mockAuthentication` default mismatch, and inverted.** Constructor default `true` (line
   10) vs `fromDefines()` default `false` (line 22). Any code path constructing
   `AppEnvironment(...)` directly silently gets **mock authentication enabled**.
3. `Environment.values.byName(name)` (line 21) throws **`ArgumentError`, not `StateError`**,
   for a typo'd `APP_ENV`. This is an `Error`, not an `Exception`, so it escapes `apiGuard`
   entirely and happens **before `runApp`** — an opaque crash with no UI. No fallback to
   `development`, no friendly diagnostic.
4. `baseUrl: url.isEmpty ? 'https://api.invalid' : url` (line 38) is **dead** in non-mock mode
   (the `StateError` above fires first). Reachable only in mock mode.
5. `Environment` is never used for behavior beyond the HTTPS gate. There is no per-environment
   base-URL table and no per-env feature flags — `APP_ENV` is nearly decorative.
6. No `toString`, no `==`/`hashCode`, no `const` construction anywhere.

### Build commands

```sh
# live CAP login (default)
flutter run

# demo authentication
flutter run --dart-define=MOCK_AUTH=true

# explicit backend
flutter run --dart-define=APP_ENV=staging --dart-define=MOCK_AUTH=false \
  --dart-define=API_BASE_URL=https://your-backend.example/api \
  --dart-define=API_VERSION=v1
```

---

## 13. AI / Copilot architecture

### Full chain

```
AiCopilotScreen                     lib/ai_copilot/ai_copilot_screen.dart
  controller = AiCopilotController(incident, client, complete)
    client   = widget.client ?? (isRegistered<AiCopilotClient> ? services<AiCopilotClient>()
                                                              : AiCopilotService.fromEnvironment())
    complete = widget.client == null && isRegistered<CompleteCopilotUseCase>()
                 ? services<CompleteCopilotUseCase>() : null
       ↓
AiCopilotController (Cubit<int>)    lib/ai_copilot/ai_copilot_controller.dart:13
  send(prompt): append user message → loading=true → notifyListeners()
       ↓
CompleteCopilotUseCase.call         lib/features/copilot/domain/complete_copilot_use_case.dart
  pure passthrough
       ↓
CopilotRepository.complete           lib/features/copilot/data/copilot_repository.dart:10-23
  Success(...)
  AiServiceException → FailureResult(ServiceFailure(error.type.name))
  Exception          → FailureResult(ExceptionMapper.map(error))
       ↓
AiCopilotService.complete            lib/ai_copilot/ai_copilot_service.dart:105-131
  mock mode → return _mockAnswer(history.last.content)     [NO NETWORK]
  blank apiKey → AiServiceException(missingApiKey)
  _request(model)  ── on modelUnavailable && model != fallbackModel ──▶ _request(fallbackModel)
       ↓
RetrofitAiTransport.post             lib/features/copilot/data/retrofit_ai_transport.dart:18-42
  api.complete(jsonDecode(body), headers['Authorization'] ?? '', null)
  200                  → AiTransportResponse(statusCode: 200, body: jsonEncode(result.data))
  DioException w/response → AiTransportResponse(real status, jsonEncode(response.data))
  DioException w/o response → rethrow
       ↓
CopilotApiService                   lib/features/copilot/data/api/copilot_api_service.dart
  @POST('/chat/completions')  — no @Extra
  Groq bearer key passed as an explicit @Header parameter
       ↓
Dio 'copilot' (baseUrl https://api.groq.com/openai/v1, no AuthInterceptor)
```

### Request shape

```json
{
  "model": "<selectedModel>",
  "messages": [
    { "role": "system", "content": "<AiCopilotPrompts.system>\n\n<incidentContext>" },
    ...last 10 history messages mapped to role user/assistant
  ]
}
```

`ai_copilot_service.dart:138-151`. History is truncated with a local
`takeLast` extension (`ai_copilot_service.dart:225-229`).

The system prompt (`lib/ai_copilot/ai_copilot_prompts.dart`) forbids inventing records,
mandates "Suggested Guidance" labelling, forbids safety bypass, and instructs language
mirroring including Egyptian Arabic.

### Provider error mapping (`ai_copilot_service.dart:172-208`)

| Condition | `AiServiceErrorType` |
|---|---|
| status 429 | `rateLimit` |
| status 404, or 400 containing `model` + (`not found` / `unavailable` / `decommissioned`) | `modelUnavailable` |
| other non-2xx | `provider('HTTP n')` |
| missing/empty `content` in the parsed body | `invalidResponse` |
| `TimeoutException` from the explicit `.timeout(25s)` (line 163) | `timeout` |
| `SocketException` / `HttpException` | `network` |

Note: `_request` catches `TimeoutException`, `SocketException` and `HttpException` but **not**
`DioException`. Since the Retrofit transport rethrows `DioException` when there is no
response (network-level failures), those become `DioExceptionType.connectionError` →
`NetworkFailure` → and finally `AiServiceErrorType.network` at
`controller.dart:65-68`. So a Dio `connectTimeout` is reported as "temporarily unavailable"
rather than "took too long".

### Mock mode

`AiCopilotService.fromEnvironment()` (line 71-87) selects
`mode = apiKey.trim().isEmpty ? AiCopilotMode.mock : AiCopilotMode.groq`. There is **no
`MOCK_AI` define** — mock mode is implied purely by an empty `GROQ_API_KEY`.

`_mockAnswer` (line 210-222) is a keyword router, not a model:
- contains `troubleshoot` → 4-step guidance
- contains `history` → site-history pointer
- contains `missing` or `next` → completion-readiness pointer
- else → generic

It ignores incident context entirely, so mock answers are identical for every incident. It
throws `StateError` on an empty history list (safe only because the controller always appends
the user turn first).

**There is no runtime fallback to mock on provider failure.** A live-mode failure produces a
friendly error bubble plus Retry; it never degrades to `_mockAnswer`.

A `_ModeBadge` in the app bar shows `GROQ` or `MOCK`, so the active mode is visible.

### Locally derived UI (deliberately not AI)

`AiCopilotController._actionsFor` (lines 115-138) keyword-matches English and Arabic
(`بعد`, `ناقص`) to produce `AiLocalAction` chips, gated on `CompletionReadiness` from
`AiCopilotContextBuilder`. `_isTroubleshooting` (lines 140-146) matches `troubleshoot` /
`diagnos` / `عطل` / `مشكلة`. AI output is treated as informational; the actionable chips are
computed entirely client-side.

### Failure round-trip fragility

`controller.dart:65-68` converts back with
`AiServiceErrorType.values.byName(failure.code)`. Any `ServiceFailure` with an unrelated code
— e.g. CAP's `'inactive_user'` — throws `ArgumentError`, which is caught by `on Object`
(line 91) and shown as the generic message. This couples a legacy enum name to the core
`Failure` hierarchy by string.

---

## 14. Mock data and prototype screens

### Dataset — `lib/mock/mock_data.dart` (870 lines, all `static const` / `static final`)

| Collection | Size | Declaration |
|---|---|---|
| `capIncidents` | **21** (IDs `INC-2026-1001` … `1021`) | line 198 |
| `towerSites` | 12 (Cairo / Giza / Alexandria / Delta, with lat/lng) | line 72 |
| `myRequests` | 6 | line 660 |
| `incidentTimeline` | 7 | line 535 |
| `notifications` | 7 (one per `AppNotificationType`) | line 606 |
| `teamMembers` | 5 (one marked unavailable) | line 24 |
| `prototypeScenarios` | 5 | line 831 |
| `questionnaireAnswers` | 5 | line 768 |
| `attachments` | 4 (one per upload state) | line 741 |
| `questions` | 4 (dropdown / yes-no / number / checkbox) | line 814 |
| `sites` | 3 | line 58 |
| `incidents` | 3 | line 171 |
| `relatedRequests` | 3 | line 582 |
| `timeline` | 3 | line 796 |
| `engineer` | 1 | line 18 |

Constants of note (lines 12-16): `activeInterventionNumber = 'INT-2026-0064'`,
`confirmationSerialNumber = 'ATS-DEP-784201'`, `sessionTimeoutMinutes = 30`,
`sessionWarningSeconds = 60`, `autoApproveSelfAssignment = true`.
Company identity (lines 7-11): "Access Technical Services", region "Cairo", team "Field Team A".

### Domain models — `lib/models/models.dart` (376 lines)

Enums: `IncidentStatus` (10 values), `Priority` (4), `CapIncidentStatus` (7),
`AttachmentState` (3), `QuestionType` (7), `RelatedRequestType` (3),
`AppNotificationType` (8), `MyRequestStatus` (4), `PrototypeScenarioType` (5).

Models: `Engineer`, `TeamMember`, `MockQuestionnaireAnswer`, `PrototypeScenario`, `Site`,
`TowerSite`, `ContactPerson`, `Incident`, `CapIncident` (20 fields), `AppNotification`,
`RelatedRequest`, `MyRequest`, `IncidentListFilter`, `AppAttachment`, `TimelineEvent`,
`QuestionnaireItem`.

Logic: `statusAfterRequestDecision()`, label extensions `CapIncidentStatusX` /
`RelatedRequestTypeX`, `copyWith` on `AppNotification` / `RelatedRequest` / `MyRequest`,
`IncidentListFilter.isActive`.

No `==`/`hashCode` overrides and no `equatable` — safe today only because no `BlocBuilder`
and no list-diffing depends on equality.

### Prototype demo — `prototype_demo_screen.dart`

A hidden scenario picker (reachable by long-pressing the "+" logo, `app_shell.dart:38`) that
drives the whole app into specific states: normal, invalid, inactive, unauthorized, loading
login previews; plus prototype scenarios from `MockData.prototypeScenarios`. It is also where
the session-timeout countdown simulation is reachable.

---

## 15. Important classes and files (quick reference)

### Core foundation

| Class | File | Responsibility |
|---|---|---|
| `AppEnvironment` / `Environment` | `lib/core/config/environment.dart` | compile-time config, `apiUrl`, validation |
| `services` (`GetIt.instance`) / `configureDependencies` | `lib/core/di/injection.dart` | all registrations; mock/live branch; refresh closure |
| `DioClient` | `lib/core/network/dio_client.dart` | Dio factory, timeouts, scoped TLS exception |
| `SafeLoggingInterceptor` | `lib/core/network/interceptors/logging_interceptor.dart` | redacted debug logging |
| `AuthInterceptor` | `lib/core/network/interceptors/auth_interceptor.dart` | token attach, cross-origin guard, single-flight refresh, replay-once |
| `ApiEndpoints` | `lib/core/network/api_endpoints.dart` | the two CAP paths |
| `ApiResponse` | `lib/core/network/api_response.dart` | `Map<String, dynamic>` newtype |
| `Result<T>` / `Success<T>` / `FailureResult<T>` | `lib/core/network/result.dart` | success/failure boundary |
| `ApiException` | `lib/core/network/api_exception.dart` | carries a `Failure` |
| `UploadApiService` | `lib/core/network/upload_api_service.dart` | **unused** multipart template |
| `ExceptionMapper` / `apiGuard` | `lib/core/error/exception_mapper.dart` | exception → `Failure` |
| `Failure` + 8 subclasses | `lib/core/error/failure.dart` | sealed error taxonomy |
| `SessionManager` / `SessionStatus` | `lib/core/session/session_manager.dart` | in-memory + persisted session, generation epoch |
| `SessionTokens` / `TokenStorage` / `SecureStorageService` | `lib/core/storage/secure_storage_service.dart` | Keychain / EncryptedSharedPreferences persistence |
| `AppRoutes` | `lib/core/routes/app_routes.dart` | route table + auth guard + transition |
| `AppTheme` / `AppColors` / `AppSpacing` / `AppRadius` / `AppTypography` | `lib/core/theme/*` | design tokens and Material 3 themes |
| `AppStrings` / `StringsX` / `MockContentLocalization` | `lib/core/localization/*` | bilingual copy helpers |

### Authentication feature

| Class | File |
|---|---|
| `AuthUser`, `LoginRequest`, `RefreshTokenRequest` | `lib/features/authentication/data/models/auth_models.dart` |
| `CapLoginResponse` | `lib/features/authentication/data/models/cap_login_response.dart` |
| `AuthApiService` | `lib/features/authentication/data/api/auth_api_service.dart` |
| `AuthRepositoryImpl`, `DemoAuthRepository` | `lib/features/authentication/data/repositories/auth_repository_impl.dart` |
| `AuthRepository` (interface) | `lib/features/authentication/domain/repositories/auth_repository.dart` |
| `LoginUseCase` | `lib/features/authentication/domain/usecases/login_use_case.dart` |
| `LoginBloc`, `LoginState`, `LoginStatus`, `LoginSubmitted` | `lib/features/authentication/presentation/bloc/login_bloc.dart` |

### Copilot feature + legacy AI

| Class | File |
|---|---|
| `CopilotApiService` | `lib/features/copilot/data/api/copilot_api_service.dart` |
| `RetrofitAiTransport` | `lib/features/copilot/data/retrofit_ai_transport.dart` |
| `CopilotRepository` | `lib/features/copilot/data/copilot_repository.dart` |
| `CompleteCopilotUseCase` | `lib/features/copilot/domain/complete_copilot_use_case.dart` |
| `AiCopilotMode`, `AiChatRole`, `AiLocalAction`, `AiChatMessage`, `CompletionReadiness` | `lib/ai_copilot/ai_copilot_models.dart` |
| `AiCopilotPrompts` | `lib/ai_copilot/ai_copilot_prompts.dart` |
| `AiProviderConfig` | `lib/ai_copilot/ai_provider_config.dart` |
| `AiCopilotService`, `AiCopilotClient`, `AiHttpTransport`, `IoAiHttpTransport`, `AiTransportResponse`, `AiServiceException`, `AiServiceErrorType` | `lib/ai_copilot/ai_copilot_service.dart` |
| `AiCopilotContextBuilder` | `lib/ai_copilot/ai_copilot_context_builder.dart` |
| `AiCopilotController` (`Cubit<int>`) | `lib/ai_copilot/ai_copilot_controller.dart` |
| `AiCopilotScreen` | `lib/ai_copilot/ai_copilot_screen.dart` |

### App shell

| Class | File |
|---|---|
| `AccessLogApp` / `AccessLogAppState` | `lib/app.dart` |
| `main` | `lib/main.dart` |
| `LoginScreen`, `ForgotPasswordScreen`, `OtpVerificationScreen`, `CreateNewPasswordScreen`, `PasswordChangedScreen` | `lib/screens/auth/auth_screens.dart` |

---

## 16. Current data flow from UI to API

### Authenticated backend call (the only one that exists)

```
Widget
  └─ Bloc / Cubit / controller
       └─ UseCase
            └─ Repository  ── apiGuard ──┐
                 └─ Retrofit Service    │ on Exception
                      └─ Dio (default)  │
                           ├─ SafeLoggingInterceptor  (redacts, then continues)
                           └─ AuthInterceptor
                                ├─ extra['public'] == true?  → pass
                                ├─ origin != baseUrl origin? → UnauthorizedFailure
                                ├─ await _refreshing
                                ├─ isAuthenticated && tokens != null?
                                ├─ Authorization: Bearer <access>
                                └─ extra['sessionGeneration'] = generation
                           → HTTPS → CAP server
                                └─ 401 → onError → single-flight _rotate
                                              → FormData.clone() / no Stream replay
                                              → retry once via dio.fetch
  ◀── Result<T>  (Success | FailureResult<Failure>)
  ◀── state / message
       └─ bilingual copy chosen by failure TYPE (never Failure.message)
```

### AI Copilot call

```
AiCopilotScreen
  └─ AiCopilotController (Cubit<int>, emit(state+1) as change signal)
       └─ CompleteCopilotUseCase
            └─ CopilotRepository  ── hand-rolled try/catch, NOT apiGuard
                 └─ AiCopilotService  (mock | groq, model fallback)
                      └─ RetrofitAiTransport
                           └─ CopilotApiService (Authorization as @Header)
                                └─ Dio 'copilot' (Groq, no AuthInterceptor)
```

### Everything else

```
Widget
  └─ const MockData.<collection>   (lib/mock/mock_data.dart)
```

No repository, no service, no abstraction. Screens reference the static dataset directly.
The only exceptions inside the mock half are the real OSM tile requests from
`flutter_map` and the `url_launcher` calls in incident details.

---

## 17. Tests: structure and coverage

11 files, **64 tests** — 40 `testWidgets`, 24 `test`. **No `group()` blocks anywhere**;
all tests are flat. No golden files.

| File | Tests | Type | Coverage |
|---|---|---|---|
| `test/network_foundation_test.dart` | 5 | unit, **fake `HttpClientAdapter`** | concurrent 401s refresh once and replay all; token lifecycle; refresh failure → single expiry; logout during refresh cannot resurrect; public 401 never starts refresh |
| `test/cap_login_contract_test.dart` | 6 | unit | request envelope + credential casing; unknown/rejected response cannot create a session; success maps identity + both tokens; failed `resultcode` rejects even with tokens; inactive mobile account rejects; missing tokens cannot establish a session |
| `test/cap_certificate_policy_test.dart` | 1 | unit | `acceptsInvalidCertificate` host/port allowlist (Groq, suffix-attacker host, non-443 all rejected) |
| `test/ai_copilot_test.dart` | 8 | 5 unit, 3 widget | context builder derives facts locally; service factory falls back to mock without a key; missing-key retry UI; Copilot UI sends prompt and exposes local actions; Copilot icon removed from Incident Details |
| `test/product_flow_test.dart` | 17 | widget | critical EN journey; Arabic RTL + dark toggle; per-status actions; wizard overflow; conditional questionnaire; mock camera; attachments/signature; location outcomes; hidden demo route; logo long-press; Arabic large text; language toggle |
| `test/session_timeout_test.dart` | 6 | 1 unit, 5 widget | session constants; countdown + Stay Logged In; expired dialog; login-again clears nav stack; intervention logout; Arabic RTL warning |
| `test/reporting_module_test.dart` | 5 | 1 unit, 4 widget | filters use the central catalogue; reporting home; KPI deep-links; engineer report site filtering |
| `test/tower_map_test.dart` | 4 | 1 unit, 3 widget | tower catalogue covers incident sites; marker preview + tower requests; search/empty state; Arabic large text |
| `test/mock_data_integrity_test.dart` | 4 | unit | `statusAfterRequestDecision`; catalogue covers all statuses; scenario/request links resolve; identity completeness |
| `test/responsiveness_test.dart` | 4 | widget | 6 viewports LTR+RTL; large system font scales; 48dp touch targets; login scroll under keyboard |
| `test/request_decision_reports_test.dart` | 3 | widget | approve/reject on a request card; request-flow report → details; engineer-sites summary |
| `test/widget_test.dart` | 1 | widget | smoke: Arabic login renders in light mode |

### Test approach worth preserving

`test/network_foundation_test.dart` defines `class TestAdapter implements HttpClientAdapter`
and drives the **real** `AuthInterceptor` + `SessionManager` against it, injecting a fake
refresh closure and an in-memory `TokenStorage`. This gives real coverage of the concurrency
logic with **no network I/O**.

No real login or refresh requests are executed in any test — verified consistent with
`ARCHITECTURE.md:148`.

### Coverage gaps

- No tests for `ExceptionMapper` in isolation, and no tests for `apiGuard` catching
  `Error` subtypes.
- No test for `AppEnvironment.fromDefines()` validation or the constructor-vs-factory default
  mismatch.
- No test asserting `session.startDemo()`'s `tokens == null` invariant.
- No test for `AuthRepositoryImpl.refresh` or `DemoAuthRepository.refresh` (both dead).
- No integration test for `AppShell` tab switching or the reporting custom painters.
- `cap_certificate_policy_test.dart` asserts
  `acceptsInvalidCertificate('test.talentlink360.com', 443) == allowCapInvalidCertificate`,
  so it **passes whether the TLS bypass is on or off** — it validates the host/port narrowing
  but cannot catch a flipped default.

---

## 18. Security-related findings

### 18.1 TLS verification disabled by default

`lib/core/network/dio_client.dart:9-12`:

```dart
static const allowCapInvalidCertificate = bool.fromEnvironment(
  'CAP_ALLOW_INVALID_CERTIFICATE',
  defaultValue: true,
);
static bool acceptsInvalidCertificate(String host, int port) =>
    allowCapInvalidCertificate &&
    host.toLowerCase() == 'test.talentlink360.com' &&
    port == 443;
```

- **Defaults to `true` and is compile-time**, so it is active in **every build mode including
  release**. The in-code comment (lines 7-8) acknowledges it is temporary and must be removed
  once the server certificate chain is repaired.
- The scoping is **correct**: exact host equality plus exact port 443. No suffix/substring
  confusion. `api.groq.com` and `test.talentlink360.com.attacker.test` are both rejected, and
  that is asserted in `test/cap_certificate_policy_test.dart`.
- Implementation is a scoped `IOHttpClientAdapter` with a `badCertificateCallback`
  (lines 33-38), installed only when the base URL scheme is `https` **and** the host/port
  match. There is **no global `HttpOverrides`** and no wildcard `SecurityContext` — verified.
- Because the callback re-evaluates host/port per connection, a redirect to the same host keeps
  the bypass. `followRedirects: false` limits this in practice.
- When the adapter is installed, the custom `HttpClient` replaces Dio's default adapter
  behavior for that instance.
- Disable with `--dart-define=CAP_ALLOW_INVALID_CERTIFICATE=false`.

`ARCHITECTURE.md:90-96` documents this exception, but frames it as "temporary" and
user-requested without stating that the **default is `true` in release builds**.

### 18.2 Android cleartext

`android/app/src/debug/res/xml/debug_network_security_config.xml`:

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain>108.181.167.130</domain>
    </domain-config>
</network-security-config>
```

Wired from `android/app/src/debug/AndroidManifest.xml` via
`android:networkSecurityConfig`. `src/main/AndroidManifest.xml` has **no**
`usesCleartextTraffic` and the **profile** manifest does not reference the config, so release
builds have no cleartext exception. This matches `ARCHITECTURE.md:40`.

### 18.3 Inverted configuration defaults

`AppEnvironment`'s constructor defaults are `apiVersion = 'v1'` and
`mockAuthentication = true`, while `fromDefines()` uses `''` and `false`. Direct construction
silently enables **mock authentication**. See section 12.

### 18.4 Error messages conflate distinct failure classes

`AuthInterceptor._expired` always produces `UnauthorizedFailure`
(`auth_interceptor.dart:13-17`). That single failure type covers:

- a genuinely wrong password,
- a cross-origin rejection (`app.dart`/`auth_interceptor.dart:29-31`),
- a missing/unauthenticated session (`auth_interceptor.dart:33-35`),
- a failed refresh (which logs the user out).

The login screen renders all of them as "Sign-in rejected. Check your username and password."
(`auth_screens.dart:236-240`). A misconfigured `API_BASE_URL` is therefore indistinguishable
from a wrong password, and a refresh failure shows the same message.

### 18.5 Disabled-account check is opt-out

`cap_login_response.dart:23-26` rejects only an explicit boolean `false`:

```dart
if (data['User_MobileEnable'] == false ||
    data['User_MobileActivationState'] == false) { ... }
```

A missing field, `null`, `"false"`, or `0` all pass, and a session is created from whatever
tokens are present. Note the asymmetry: `User_PK_ID` is type-strict (`is num`) while these
two flags are value-lenient. Given that the whole design goal is "a HTTP 200 alone never
establishes a session", this is the weakest link in the parser.

### 18.6 Log redaction gaps

- The key regex does not cover `sessionId`, `userid`, or `ipaddress`. The CAP `ipaddress`
  value (`FUH0216913004222` by default) is logged verbatim.
- Content sniffing only recognizes `Bearer\s` and the JWT shape `eyJ[A-Za-z0-9_-]+\.`. A
  non-JWT opaque bearer token embedded in free text is not detected.
- The post-serialization scrub (lines 90-108) is a **global `replaceAll`** over the encoded
  output. A short credential value will redact unrelated substrings across the whole log
  block, making the log misleading.
- The `'copilot'` Dio is created with `logging: config.logging`, so in debug the full incident
  context (site name/code, region, area, engineer name, company, team, issue description) and
  the model's reply are logged. Redaction is key- and pattern-based, **not PII-aware**.
- Mitigating: the interceptor is only attached when `logging == true`, and `logging` is
  `kDebugMode && API_LOGGING` (`environment.dart:41-43`). It also double-guards with
  `if (!kDebugMode) return`. **Release builds never log.**

### 18.7 Platform hardening gaps

Verified by inspecting the platform directories:

- **iOS: no `.entitlements` files at all** — `ls ios/Runner/*.entitlements` returns nothing,
  and no `CODE_SIGN_ENTITLEMENTS` build setting. Keychain sharing / access groups are not
  configured. `SecureStorageService` passes no `IOSOptions`.
- **Android: no `android:allowBackup="false"`, no `dataExtractionRules`, no
  `fullBackupContent`** in `src/main/AndroidManifest.xml`. Android Auto Backup could capture
  the secure-storage SharedPreferences.
- `SecureStorageService` uses bare `const FlutterSecureStorage()` — no
  `AndroidOptions(encryptedSharedPreferences: true)`.
- `ARCHITECTURE.md:145-148` flags both of these as "verify on real devices". **They remain
  unaddressed.**

### 18.8 Release signing

`android/app/build.gradle.kts:37` uses `signingConfig = signingConfigs.getByName("debug")`
for the release build type, with a TODO comment still in the file.

### 18.9 AI provider key in the client

`GROQ_API_KEY` is compiled into the binary via `--dart-define`. A mobile client cannot keep it
secret. `ARCHITECTURE.md:114-115` acknowledges this and recommends a backend proxy for a
public production release. The *isolation* is real though: the `'copilot'` Dio has no
`AuthInterceptor`, so the provider key never enters the app refresh flow.

### 18.10 Other

- `CopilotApiService.complete` has **no** `@Extra({'public': true})`. This is safe only
  because the `'copilot'` Dio has no `AuthInterceptor`. If it were ever re-pointed at the
  default Dio, the Groq key would be replaced by the CAP session token and the cross-origin
  check would reject the request. There is no comment or assert guarding this.
- Android permissions: `INTERNET` only (main + debug + profile manifests).
- iOS `Info.plist` has no usage descriptions — no camera, location, or photo library entries —
  even though the app has `PhotoCaptureScreen`, `SignaturePadView` and GPS validation screens.
  On a real device, camera/location capture would fail. **`Needs Verification`** — prototype
  screens use a mock photo picker, so this may simply be unused surface area, but the screen
  code exists and would need permissions if made real.
- iOS deployment target is 13.0 (`ios/Runner.xcodeproj/project.pbxproj`), and the `Podfile`
  platform line is commented out (`# platform :ios, '13.0'`).
- Android SDK versions are inherited from Flutter (`compileSdk = flutter.compileSdkVersion`,
  etc.) rather than pinned. Java 17 / `jvmTarget 17`.

---

## 19. Dead code and duplicated code

### Dead code (no live callers)

| Item | File | Notes |
|---|---|---|
| `IoAiHttpTransport` | `lib/ai_copilot/ai_copilot_service.dart:40-59` | Never instantiated in `lib/` or `test/`. Its `SocketException`/`HttpException` catches (lines 166-169) are therefore also dead in the Retrofit path. |
| `AuthRepositoryImpl.refresh` | `lib/features/authentication/data/repositories/auth_repository_impl.dart:29-44` | `AuthRepository.refresh` is on the domain interface but **nothing calls it**. The live refresh lives in the DI closure. |
| `DemoAuthRepository.refresh` | `lib/features/authentication/data/repositories/auth_repository_impl.dart:61-63` | Same. |
| `AuthUser.fromJson` / `AuthUser.toJson` | `lib/features/authentication/data/models/auth_models.dart:4-6` | Never called. The CAP path constructs `AuthUser` directly. Artifact of the retired generic `{id, name}` contract. |
| `CapLoginResponse.parse`'s `username` parameter | `lib/features/authentication/data/models/cap_login_response.dart:14` | **Never read inside the function.** Identity comes wholly from the response. `cap_login_contract_test.dart` even asserts this by passing a mismatched value. |
| `UploadApiService` | `lib/core/network/upload_api_service.dart` | Registered nowhere, referenced nowhere in `lib/`. Only its own `.g.dart` mentions it. |
| `baseUrl: url.isEmpty ? 'https://api.invalid' : url` | `lib/core/config/environment.dart:38` | Unreachable in non-mock mode (the `StateError` fires first). |
| `json_annotation` (dependency) | `pubspec.yaml:47` | No `@JsonSerializable` anywhere. All models hand-write `toJson()`. `json_serializable` (dev) is likewise unused. |
| `SessionStatus.expired` distinction | `lib/core/session/session_manager.dart:4` | Never surfaced to the UI — `app.dart:27` only tests `!= authenticated`. |

### Duplicated code

**1. CAP refresh parsing implemented twice, with divergent error types:**

| Location | On `resultcode != 1` |
|---|---|
| `lib/core/di/injection.dart:57-59` | `throw const FormatException('Refresh token failed')` |
| `lib/features/authentication/data/repositories/auth_repository_impl.dart:31-33` | `throw const ApiException(UnauthorizedFailure())` |

Only the DI closure runs. They must be kept in sync manually and already disagree.

**2. CAP metadata block duplicated verbatim** in `LoginRequest.toJson()`
(`auth_models.dart:14-34`) and `RefreshTokenRequest.toJson()` (`auth_models.dart:44-63`) —
five `String.fromEnvironment` blocks copied. `RefreshTokenRequest` omits `lang`, so the
refresh envelope has one fewer field than the login envelope.

**3. `navigateToSecureLogin` has two divergent behaviors** depending on whether
`SessionManager` is registered (`lib/widgets/session_timeout_ui.dart:13-23`).

**4. `RetrofitAiTransport` has an optional-constructor escape hatch** that creates a
**second, unconfigured Dio** when DI is absent (`retrofit_ai_transport.dart:10-15`). The
screen's non-DI fallback (`ai_copilot_screen.dart:34`) reaches it, and `AiCopilotService._request`
also lazily does `(_transport ??= RetrofitAiTransport())` (`ai_copilot_service.dart:154`).

### Minor dead code inside expressions

- `retrofit_ai_transport.dart:36` — `error.response!.statusCode ?? 500`. Dio's
  `Response.statusCode` is a non-nullable `int`, so the `?? 500` is unreachable.
- `RetrofitAiTransport.post` **ignores its `uri` argument** and always targets
  `/chat/completions` on `AiProviderConfig.baseUrl` (line 24-28). It also drops the
  `Content-Type` header it is handed. The `AiHttpTransport` contract is narrower than it
  appears; a second provider added through it would silently post to Groq.
- `ApiResponse.toJson()` returns the **same map reference**, not a copy.
- `LoginBloc`'s `if (state.status == LoginStatus.loading) return;`
  (`login_bloc.dart:23`) is effectively unreachable — bloc's default transformer is
  sequential, so by the time a second `LoginSubmitted` is handled the state is already
  terminal. The real re-entrancy guard is in the UI (`auth_screens.dart:_login`).

---

## 20. Documentation vs code inconsistencies

`ARCHITECTURE.md` is a prior handoff document. The following statements do not match the code.
**In every case the code is what runs.**

### Direct contradictions

1. **`ARCHITECTURE.md:47-48`** — *"CAP refresh was not supplied, so no requests are made to an
   invented refresh endpoint."*
   **False.** `ApiEndpoints.refresh = '/CAP/CapAuth/RefreshToken'` (`api_endpoints.dart:3`) is
   declared, wired into `AuthApiService.refresh`, and **actively called** by the closure in
   `injection.dart:55-69` on the first 401 of any live session. This is the most consequential
   doc/code divergence in the project.

2. **`ARCHITECTURE.md:107`** — *"All backend services share the DI Dio singleton."*
   There are **three** Dio instances. The Groq isolation at line 111 contradicts line 107
   within the same document.

3. **`ARCHITECTURE.md:145`** — *"Generated `.g.dart` files belong in source control."*
   `git ls-files | grep '\.g\.dart'` returns **0 results**. All three generated files
   (`auth_api_service.g.dart`, `copilot_api_service.g.dart`, `upload_api_service.g.dart`)
   exist on disk but are untracked. `lib/features/` has **0** tracked files.

4. **`ARCHITECTURE.md:98-105`** — *"SessionManager owns in-memory credentials, serialized secure
   persistence, restore, logout and expiration."*
   Serialized persistence / restore / logout are accurate. **Expiration does not exist** —
   `SessionManager` has no timer and no expiry logic.

5. **`ARCHITECTURE.md:51-81`** still presents the retired generic `{username, password}` /
   `{accessToken, refreshToken, user}` contract and `auth/refresh` as "Authentication contract
   to confirm with backend", under the heading "Authentication contract to confirm with
   backend". The label "historical" appears, but the block is still framed as the contract to
   confirm. The code uses the CAP envelope exclusively.

6. **`ARCHITECTURE.md:90-96`** frames the TLS exception as temporary and gated, but does not
   state that the default is `true` **in every build including release**.

7. **`ARCHITECTURE.md:132`** (the "New endpoints" recipe, step 3) says to wrap repository
   operations with `apiGuard`. `CopilotRepository` — the one repository in the new layer that
   performs network work — does not use it.

### Incomplete / drifted

8. **`ARCHITECTURE.md:5-26`** file tree omits `lib/core/routes/`, `lib/core/localization/`,
   `lib/core/theme/`, `lib/core/network/api_exception.dart`,
   `lib/features/authentication/data/models/cap_login_response.dart`, all `*.g.dart` files, and
   the entire `lib/ai_copilot/**` + `lib/screens/auth` + `lib/widgets/session_timeout_ui.dart`
   legacy half that the new feature layer **imports**. The tree implies a self-contained
   `core` + `features`; the reality is that `features/*` and `core/di` depend on legacy
   root-level folders.

9. **`ARCHITECTURE.md:150-153`** ("Modified existing files") omits
   `lib/features/copilot/**`, `cap_login_response.dart`, `lib/mock/mock_data.dart`, and the
   `android/app/src/debug/**` manifest + network-security-config additions.

10. **`ARCHITECTURE.md:142`** — the test command runs only
    `test/network_foundation_test.dart test/ai_copilot_test.dart`. The suite also contains
    `cap_certificate_policy_test.dart`, `cap_login_contract_test.dart`,
    `session_timeout_test.dart`, `mock_data_integrity_test.dart`, `product_flow_test.dart`,
    `reporting_module_test.dart`, `request_decision_reports_test.dart`,
    `responsiveness_test.dart`, `tower_map_test.dart`, `widget_test.dart`.

11. **`ARCHITECTURE.md:36-37`** lists six `CAP_*` overrides for "the CAP envelope". 
    `RefreshTokenRequest` omits `CAP_LANGUAGE` / `lang`.

12. **`ARCHITECTURE.md:44-46`** says "resultcode must equal 1; data contains User_PK_ID,
    User_Name, AccessToken and RefreshToken. Explicitly disabled mobile accounts are
    rejected." Accurate but incomplete: it does not mention that `User_PK_ID` must be
    `num` (a string id is rejected), that both tokens must be non-blank, or that
    `CapLoginResponse.parse` takes an unused `username`.

13. **`README.md`** is unmodified Flutter boilerplate ("A new Flutter project") and describes
    nothing about this application. It is not a useful entry point.

### Claims verified as accurate

- Default `flutter run` hits the CAP test login with `MOCK_AUTH=false`.
- `--dart-define=MOCK_AUTH=true` restores demo auth.
- CAP metadata are fixed test values, not detected device info; `CAP_DEVICE_TYPE` defaults to
  the literal `'iOS'`.
- Debug-only logging; recursive redaction; truncation; file bytes omitted; `API_LOGGING=false`
  to disable; release never logs.
- Separate refresh Dio prevents interceptor recursion.
- Cross-origin refusal and no-session rejection for protected calls.
- `@Extra({'public': true})` on public Retrofit methods.
- Groq isolated from application credentials.
- Lazy service/repository/use-case + factory bloc.
- `UploadApiService` is an unused generated template.
- Android debug allows HTTP only to `108.181.167.130`; no cleartext exception in release.
- No global `HttpOverrides`; the bad-cert callback is scoped to host + port.
- "Modified existing files" are indeed all modified (`git status` confirms 11 modified).
- No real login or refresh requests in unit tests.

---

## 21. Known risks and technical debt

### High

1. **An invented refresh endpoint is enabled in a live code path.** `/CAP/CapAuth/RefreshToken`
   is unconfirmed — `ARCHITECTURE.md:47-48` states refresh was never supplied. It fires on the
   first 401 of any protected request. If the path 404s, `_rotate` throws →
   `session.logout(expired: true)` → the user is silently signed out on a transient server
   error, with a message that reads like a wrong password. **Whether this endpoint exists on
   the CAP test server is `Needs Verification`** — it cannot be determined from the codebase.

2. **TLS verification disabled by default in all build modes**, scoped correctly to
   `test.talentlink360.com:443` (`dio_client.dart:9-16`). Documented and intentional, but the
   default is on the risky side, there is no build-time guard forcing it off for release, and
   no expiry. `ARCHITECTURE.md:41` claims "no broad cleartext exception was added to release
   builds" — true for cleartext, but the cert bypass is present in release.

3. **Error-message conflation** — cross-origin rejection, missing session, and refresh failure
   all surface as `UnauthorizedFailure` → "check your username and password" (section 18.4).

4. **Disabled-account check is opt-out** (section 18.5) — a missing or string `"false"` flag
   establishes a session.

5. **`apiGuard` does not catch `Error`s**, and `AppEnvironment.fromDefines()` throws
   `StateError`/`ArgumentError` (both `Error`s) **before `runApp`**. One typo in a CI
   dart-define produces an opaque crash with no UI and no handler.

6. **Untracked source.** `git ls-files lib/features` → 0; `git ls-files lib/core` → 5 (only
   localization, routes, theme). The entire `core` foundation and both features, plus all
   three `.g.dart` files and `ARCHITECTURE.md`, exist only on disk. Work would be lost on a
   clean checkout.

### Medium

7. **Refresh race when the failing token is not the current one.** If
   `request.headers['Authorization'] != 'Bearer ${session.tokens?.accessToken}'`,
   `onError` skips `await _refreshing` entirely and retries with whatever the current token
   is — which may be the stale one if a rotate is mid-flight. `authRetried: true` then blocks
   a second attempt, so the request fails even though a refresh would have succeeded
   (`auth_interceptor.dart:76-84`).

8. **`startDemo()` violates an invariant** — `status == authenticated` with `tokens == null`
   (`session_manager.dart:55-60`). `AuthInterceptor.onRequest` categorically rejects that
   combination. Harmless today because mock mode never uses the shared Dio, but it will break
   the moment mock mode is used for anything beyond login.

9. **Mock mode never clears secure storage** and skips `restore()`, so tokens from a previous
   real session persist on disk and are resurrected by the next non-mock launch.

10. **`ApiEnvironment` constructor defaults are inverted** relative to `fromDefines()`
    (`mockAuthentication: true` vs `false`) — direct construction silently enables mock auth.

11. **`AiServiceErrorType` ↔ `ServiceFailure` string round-trip** (`controller.dart:65-68`)
    throws `ArgumentError` for any foreign code such as CAP's `'inactive_user'`.

12. **`Result` semantics violated in the copilot path.** `CopilotRepository` catches
    `on Exception` only. `retrofit_ai_transport.dart:35-38` does
    `jsonEncode(error.response!.data)`; a null body becomes `"null"`, then
    `ai_copilot_service.dart:186` casts it to `Map<String, dynamic>` → **`TypeError`, an
    `Error`** → escapes `CopilotRepository` and is only caught by `on Object` at
    `controller.dart:91`. The user sees a generic message, but the `Result` contract is not
    honoured. The same applies to the `_result.data!` force-unwrap on a 200 with a non-map
    body.

13. **Probable invalid default Groq model.** `AiProviderConfig.model` defaults to
    `'qwen/qwen3.6-27b'` (`ai_provider_config.dart:9-12`). The name does not resemble a Groq
    model identifier. If it does not resolve, `_isModelUnavailable` fires and the code
    **silently falls back** to `llama-3.1-8b-instant` (line 13) — masking the
    misconfiguration. A commented-out alternative (`'openai/gpt-oss-20b'`, line 14) suggests
    the value was being tuned. **`Needs Verification`** — confirm against Groq's current model
    list; cannot be checked from the codebase.

14. **PII in debug logs via the copilot Dio** — the full incident context and model replies
    are logged; redaction is key-based, not PII-aware (section 18.6).

15. **Platform hardening gaps** — no iOS entitlements, no Android `allowBackup=false`, no
    backup rules (section 18.7).

16. **`AiCopilotScreen` can construct a second, unconfigured Dio** via the non-DI fallback
    (`ai_copilot_screen.dart:34`), bypassing the DI `'copilot'` instance and its logging
    configuration.

17. **Two live navigation paths into the incident list** (shell tab index 1 and the named
    route `AppRoutes.incidentList`), producing separate widget instances with separate state.

### Low

18. **`AppRoutes.incidentDetails` does `settings.arguments! as CapIncident`**
    (`app_routes.dart:52`) — crashes on a deep link or route restoration without arguments.

19. **Unknown routes fall through to `const LoginScreen()`** (`app_routes.dart:54`). There is no
    `onUnknownRoute`, so a typo'd route name silently renders the login screen.

20. **`AiCopilotController extends Cubit<int>`** used as a change notifier
    (`emit(state + 1)`, `controller.dart:31-33`). This defeats `BlocBuilder`, `buildWhen`, and
    equality checks. `dispose()` calls `unawaited(close())` rather than `await close()`
    (lines 35-37), so the screen must cancel its subscription in the correct order.

21. **`SessionManager` fields are public and mutable** with no encapsulation.

22. **No `==`/`hashCode` on any state or model class** and no `equatable` dependency. Safe
    today only because `BlocBuilder` is never used and no list diffing depends on equality.

23. **`restore()` bypasses the `_serialize` write chain** and emits no change event, so it is
    the one storage operation not ordered against writes.

24. **`SessionTokens.fromJson` treats a missing refresh token as `''`** rather than an error,
    and `AuthInterceptor._rotate` only null-checks — so it can fire a refresh request with an
    empty refresh token (`secure_storage_service.dart:9`, `auth_interceptor.dart:50-51`).

25. **`followRedirects: false` combined with no 3xx arm in `ExceptionMapper`** means any 3xx
    becomes `UnknownFailure`.

26. **`apiVersion` default mismatch** (`'v1'` in the constructor vs `''` from `fromDefines()`).

27. **List truncation in the logger is silent** — `.take(100)` drops items with no marker.

28. **`MultipartFile.fromFileSync`** in `upload_api_service.g.dart` performs a synchronous file
    read on the Dart isolate. For the evidence photos this app collects, the async
    `MultipartFile.fromFile` would be safer. (Currently unreachable — the service is unused.)

29. **Login navigation is un-awaited and can be pushed twice** from stacked dialogs
    (section 10).

### No TODO/FIXME/HACK markers

There are **no** `TODO`, `FIXME` or `HACK` comments in `lib/core`, `lib/main.dart`,
`lib/app.dart`, `lib/features`, or `test/`. Technical debt is expressed as prose comments
(`injection.dart:37`, `auth_interceptor.dart:91`, `dio_client.dart:7-8`,
`upload_api_service.dart:7`) and in `ARCHITECTURE.md`.

---

## 22. Things that are implemented well

Worth preserving deliberately:

1. **Single-flight refresh with a generation epoch.** `AuthInterceptor._refreshing ??=
   _rotate(session.generation)` with the `identical(...)` cleanup
   (`auth_interceptor.dart:78-83`), plus `epoch != session.generation` re-checks in three
   separate places, plus `SessionManager.rotate` re-validating inside the serialized write
   (`session_manager.dart:43-53`). This is the correct answer to a genuinely hard concurrency
   problem, and `network_foundation_test.dart` covers concurrency, single-expiry,
   no-second-loop, logout-during-refresh, and public-401-never-refreshes.

2. **A separate refresh transport genuinely prevents recursion.** The `'refresh'` Dio has no
   `AuthInterceptor`.

3. **Streams are not replayed; `FormData` is cloned** (`auth_interceptor.dart:92-98`) — the two
   easy-to-get-wrong cases in request retry, both handled.

4. **A HTTP 200 never establishes a session.** `CapLoginResponse.parse` is explicit, typed,
   strict, and unit-tested against synthetic fixtures including the negative case "failed
   `resultcode` rejects even with valid tokens present"
   (`test/cap_login_contract_test.dart:51`).

5. **Both tokens share one storage record** (`secure_storage_service.dart:47-50`) so a rotation
   cannot leave a mixed pair.

6. **Scoped certificate bypass** — exact host + port predicate with a dedicated test asserting
   the Groq host and a suffix-attacker host are both rejected.

7. **Redaction is defense-in-depth** — key regex, `Bearer`/JWT content sniffing, depth cap,
   list cap, size truncation, FormData byte-counting instead of file contents, and a second
   post-serialization scrub pass. Log URLs are rebuilt from parts so user-info and raw query
   strings never reach the log.

8. **Real Groq credential isolation** — the `'copilot'` Dio has no `AuthInterceptor` and the key
   is passed as an explicit per-call `@Header`, so the provider key never enters the
   application refresh flow.

9. **AI output is treated as informational.** Action chips, completion readiness, and the
   "Suggested Guidance" label are all derived locally by keyword matching; the system prompt
   forbids inventing incident records. The app degrades gracefully — the error bubbles say
   explicitly that the incident workflow remains available.

10. **`apiGuard` keeps transport errors out of the domain**, and the UI maps failures by
    **type** to bilingual copy rather than surfacing core English strings, which keeps UI copy
    independent of the core layer.

11. **Release builds never log** — `kDebugMode &&` in the config plus a second
    `if (!kDebugMode) return;` guard inside the interceptor.

12. **Fail-closed auth routing.** `onGenerateRoute` rejects any non-public route when
    unauthenticated in live mode (`app_routes.dart:25-39`), and logout clears the whole
    navigation stack so the back button cannot re-enter authenticated screens.

13. **Good widget-test coverage of UX that matters** — 17 product-flow tests including Arabic
    RTL, dark mode, large system font scales, 48dp touch targets, and keyboard-scroll
    behavior under a 70-line responsiveness suite.

---

## 23. Things that may need refactoring later

Not recommendations to act on now — just the refactoring seams that exist.

| Area | Current shape | Seam for a future change |
|---|---|---|
| Auth domain interface | `lib/features/authentication/domain/repositories/auth_repository.dart` imports `data/models/auth_models.dart` | Move `AuthUser` to a domain-level model file so `domain` no longer depends on `data` |
| Copilot layering | `AiCopilotService` (the real orchestrator) lives in `lib/ai_copilot/`, not `features/copilot/` | Migrating it into `features/copilot/` would finish the migration that the transport layer already started |
| Refresh parsing | two copies with divergent error types (section 19) | Move the DI closure's parsing into `AuthRepositoryImpl.refresh` and inject the repository (or an `AuthRepository.refresh`) as the callback |
| CAP metadata | duplicated `String.fromEnvironment` block in two request classes | Extract to one shared `const` map or a `CapMetadata` class; decide whether `lang` belongs in the refresh envelope |
| Bloc consumption | manual `StreamSubscription` + manual `close()` in `auth_screens.dart` | `BlocProvider`/`BlocBuilder` are already available via `flutter_bloc`; would also remove the manual close ordering |
| `AiCopilotController` state | `Cubit<int>` as a change notifier | A real `Cubit<CopilotState>` with a proper state class, enabling `BlocBuilder`/`buildWhen` |
| Error type mapping | `ServiceFailure(code: String)` ↔ `AiServiceErrorType.values.byName(...)` | An explicit mapping function, or a typed error channel instead of a string code |
| `apiGuard` adoption | used by one of two repositories | Route `CopilotRepository` through `apiGuard`, or narrow `apiGuard`'s doc comment to match reality |
| `AppEnvironment` | constructor defaults diverge from `fromDefines()` | Make `fromDefines()` the only constructor, or align the defaults and require explicit values |
| Copilot transport | `RetrofitAiTransport.post` ignores `uri` and `Content-Type` | Narrow the `AiHttpTransport` interface to match reality, or honor the arguments |
| `Failure` | no `toString()`, no equality | `toString()` for debuggability; `==`/`hashCode` if state equality is ever needed |
| Result | no `map`/`fold`/`isSuccess` helpers | Add only when a second consumer needs them |
| Routing | string constants + `switch`; `_` falls through to login | `onUnknownRoute`, and a safe handling of the `incidentDetails` argument cast |
| Secure storage | bare `FlutterSecureStorage()` | Add `AndroidOptions(encryptedSharedPreferences: true)` and iOS accessibility options; add the missing entitlements and backup rules |
| Uploads | `UploadApiService` template unused, sync file reads, guessed endpoint | Confirm the backend contract before wiring it into the evidence UI |

---

## 24. Assumptions and unclear areas

Everything below is **`Needs Verification`** — it could not be settled from the codebase alone.

1. **Does `/CAP/CapAuth/RefreshToken` exist on the CAP test server?** The code calls it;
   `ARCHITECTURE.md:47-48` says refresh was never supplied. Needs confirmation from the
   backend owner or an actual request trace.

2. **Is `'qwen/qwen3.6-27b'` a valid Groq model identifier?** (`ai_provider_config.dart:9-12`).
   If not, every build without `--dart-define=GROQ_MODEL` silently falls back to
   `llama-3.1-8b-instant`.

3. **What does the CAP server actually return for a failed login?** Every non-1 `resultcode`
   becomes `UnauthorizedFailure` → "check your username and password". Whether the server
   distinguishes credential errors from locked/disabled/server-fault accounts is unknown, and
   the app currently cannot represent the difference.

4. **Are `User_MobileEnable` / `User_MobileActivationState` guaranteed present and boolean?**
   The parser only rejects an explicit `false`. If CAP omits them, `null`, or returns strings,
   disabled accounts would pass.

5. **Why is the certificate chain invalid for `test.talentlink360.com`?** The comment says
   "after the server certificate chain is repaired", implying a server-side fix is pending.
   Nothing in the repo tracks that.

6. **Is the `CAP_DEVICE_TYPE` default `'iOS'` intentional for Android builds?** It is a
   hardcoded literal, so Android sends `devicetype: "iOS"`.

7. **Is the TLS bypass required at all?** If the CAP test certificate has been repaired, the
   exception can be removed entirely. No verification of the live certificate is possible
   from the repo.

8. **iOS runtime behavior with an invalid certificate.** `ARCHITECTURE.md:41-42` says "Apple ATS
   HTTP behavior must be verified on the target iPhone". Untested. The Dart-side
   `badCertificateCallback` works on iOS only to the extent Dart's `HttpClient` is used, and
   whether Flutter's iOS networking routes through it for all requests is `Needs Verification`.

9. **Do the iOS/Android platform plugins work on a real device?**
   `flutter_secure_storage` requires Keychain entitlements and Android backup handling that
   are not configured. `ARCHITECTURE.md:145-148` flags both.

10. **Is the reporting module's custom-painting output visually verified?** There are widget
    tests for filtering and deep-linking but no golden files, and no tests for the KPI
    painters.

11. **Are there backend contracts for anything other than login/refresh?** `ApiEndpoints` has
    two entries. Every other screen is mock-backed. The intended production endpoints are
    unspecified.

12. **Is `IPHONEOS_DEPLOYMENT_TARGET = 13.0` sufficient** for the current package set
    (`flutter_secure_storage 11.2.0`, `flutter_map 8.3.1`, `dio 5.11.1`)? The Podfile platform
    line is commented out, so CocoaPods infers the minimum from the packages.
    `Needs Verification` against a real `pod install` on a clean checkout.

13. **Was the Groq model being tuned at the time of writing?** The commented-out
    `fallbackModel = 'openai/gpt-oss-20b'` (`ai_provider_config.dart:14`) suggests active
    experimentation with no settled choice.

14. **Is the two-path access to the incident list intentional?** Shell tab index 1 and the
    named `AppRoutes.incidentList` both reach `IncidentListScreen` with independent state.

---

## Recommended Reading Order

Read in this order. Steps 1-6 give you the runtime picture; 7-12 give you the architecture;
the rest is depth. Every file below exists at the stated path.

### Step 1 — Orientation (10 minutes)

1. `README.md` — **skip**; it is unmodified Flutter boilerplate. Read `ARCHITECTURE.md`
   instead but treat it as partly stale (see section 20).
2. `pubspec.yaml` — package name, Dart SDK, the full dependency list.
3. `lib/main.dart` (9 lines) — the entire bootstrap.
4. `lib/app.dart` (70 lines) — `MaterialApp`, session listener, theme and locale state.
5. `lib/core/routes/app_routes.dart` (68 lines) — the route table and the auth guard.
6. `lib/screens/app_shell.dart` — the 4-tab shell and the hidden prototype-demo gesture.

### Step 2 — Configuration and wiring (20 minutes)

7. `lib/core/config/environment.dart` (46 lines) — every `dart-define`, the validation rules,
   and the constructor/`fromDefines()` default mismatches.
8. `lib/core/di/injection.dart` (110 lines) — **the single most informative file**. The full
   DI table, the mock/live branch, all three Dio instances, and the inline CAP refresh parser.

### Step 3 — Networking core (30 minutes)

9. `lib/core/network/dio_client.dart` (43 lines) — the Dio factory, timeouts, and the scoped
   TLS exception.
10. `lib/core/network/api_endpoints.dart` (4 lines) — the only two CAP paths.
11. `lib/core/network/result.dart` (15 lines) and `lib/core/error/failure.dart` (37 lines) —
    the `Result`/`Failure` vocabulary used everywhere below.
12. `lib/core/error/exception_mapper.dart` (37 lines) — the exception→`Failure` mapping table
    and `apiGuard`.
13. `lib/core/network/interceptors/logging_interceptor.dart` (167 lines) — redaction,
    truncation, the three log stages.
14. `lib/core/network/interceptors/auth_interceptor.dart` (112 lines) — **read twice.** Once
    for what it does, once for the concurrency logic.

### Step 4 — Session and storage (15 minutes)

15. `lib/core/storage/secure_storage_service.dart` (53 lines) — `SessionTokens`, the
    `TokenStorage` seam used by tests, and the single-record token layout.
16. `lib/core/session/session_manager.dart` (71 lines) — state, serialized writes, the
    generation epoch, and the absence of expiry.

### Step 5 — Authentication end to end (25 minutes)

17. `lib/features/authentication/data/models/auth_models.dart` (66 lines) — the CAP request
    envelopes and the `CAP_*` defines.
18. `lib/features/authentication/data/models/cap_login_response.dart` (45 lines) — the
    response contract, including the two loose spots.
19. `lib/features/authentication/data/api/auth_api_service.dart` (17 lines) — Retrofit plus
    `@Extra({'public': true})`.
20. `lib/features/authentication/data/repositories/auth_repository_impl.dart` (64 lines) —
    the real and demo repositories, and the dead `refresh` that duplicates the DI closure.
21. `lib/features/authentication/presentation/bloc/login_bloc.dart` (38 lines) — the smallest
    bloc in the project; a good template.
22. `lib/screens/auth/auth_screens.dart` — the failure→bilingual-message mapping table
    (around lines 225-256) and the manual bloc subscription.

### Step 6 — AI Copilot end to end (25 minutes)

23. `lib/ai_copilot/ai_provider_config.dart` (15 lines) — Groq URL, key, model, fallback.
24. `lib/ai_copilot/ai_copilot_service.dart` (230 lines) — mock/groq selection, model fallback,
    error mapping, content extraction. Contains the dead `IoAiHttpTransport`.
25. `lib/features/copilot/data/retrofit_ai_transport.dart` (43 lines) — the legacy-interface /
    new-Dio bridge.
26. `lib/features/copilot/data/copilot_repository.dart` (24 lines) — the `Result` boundary that
    does **not** use `apiGuard`.
27. `lib/ai_copilot/ai_copilot_controller.dart` (160 lines) — `Cubit<int>` as a change notifier,
    and the local action/readiness derivation.
28. `lib/ai_copilot/ai_copilot_models.dart` and `ai_copilot_prompts.dart` — the shared types
    that the "new" domain layer depends on.

### Step 7 — Product surface (as needed)

29. `lib/models/models.dart` (376 lines) — every model and enum in the app.
30. `lib/mock/mock_data.dart` (870 lines) — the dataset driving every non-auth screen.
31. `lib/core/theme/app_tokens.dart` and `app_theme.dart` — the design system.
32. `lib/core/localization/app_strings.dart` (30 keys) and
    `mock_content_localization.dart` (44 keys) — how bilingual copy works without ARB/gen-l10n.
33. `lib/screens/incidents/incident_details_screen.dart` and
    `lib/screens/reporting/reporting_screen.dart` (3212 lines, the largest file) — the two
    biggest screens.
34. `lib/widgets/dynamic_questionnaire.dart` and `lib/widgets/evidence_collection.dart` — the
    most complex reusable widgets.

### Step 8 — Tests (before changing anything)

35. `test/network_foundation_test.dart` — **the best file in the repo.** `TestAdapter`
    exercises the real interceptor and session manager with zero network I/O. Use it as the
    template for any new networking test.
36. `test/cap_login_contract_test.dart` — the CAP response rules, positive and negative.
37. `test/product_flow_test.dart` (17 tests) — the behavioural contract of the UI.
38. `test/session_timeout_test.dart` — navigation-stack clearing on logout.

### Step 9 — Platform configuration (when touching platform code)

39. `android/app/build.gradle.kts` — Java 17, inherited SDK versions, release signed with debug
    keys.
40. `android/app/src/debug/AndroidManifest.xml` and
    `android/app/src/debug/res/xml/debug_network_security_config.xml` — the debug-only
    cleartext exception for `108.181.167.130`.
41. `android/app/src/main/AndroidManifest.xml` — note the **absence** of `allowBackup` and
    backup rules.
42. `ios/Runner/Info.plist` and `ios/Runner.xcodeproj/project.pbxproj` — deployment target 13.0;
    note the **absence** of entitlements and of usage descriptions for camera/location.

### Step 10 — Platform-safe reading (optional)

43. `ARCHITECTURE.md` — the prior handoff. Read it for intent, then verify every claim against
    the code using section 20 of this document as the checklist.

---

*Document generated by source inspection only. No project file was modified, added, moved, or
deleted in its creation.*