# Forgot Password — CAP integration

## Flow

Login → Forgot Password → enter username → Send Reset Link → email confirmation
with the backend's expiry duration → return to Login.

The existing ForgotPasswordScreen and AuthScaffold are reused. This route no
longer opens the prototype OTP/password-change screens. The backend sends the
email and handles resetting the password; the mobile app does neither itself.

`ForgotPasswordCubit → ForgotPasswordUseCase → AuthRepository → AuthApiService`
uses the existing GetIt graph, Dio, Retrofit, CapRequest and Result/Failure
conventions. Loading is single-flight and confirmation requires resultcode 1,
emailSent true and a positive linkExpiresInMinutes. Business failures preserve
the selected Arabic/English backend message. Other failures stay retryable.
Demo authentication never claims that a real email was sent.

## Public envelope and security

POST `CAP/CapAuth/ForgotPasswordRequestReset` sends `data.UserName` and userid 0.
`wrapUnauthenticated` never reads the session/stored identity. Existing `wrap`
and metadata-only authenticated envelopes keep their original behavior/JSON.

The existing device-info provider resolves OS, platform, app version and any
available push token. A CAP_DEVICE_ID override is respected; otherwise a random
128-bit installation ID is stored in existing secure storage and reused. This
is a per-install identifier, not a hardware serial number or a network IP.
No sample device/token values are embedded in the feature. Until push
registration is configured, the existing device-token fallback can be empty.

The Retrofit endpoint sets public=true, bypassing refresh/session validation
and automatic 401 logout in AuthInterceptor. Its endpoint-specific
omitAuthorization flag also removes an inherited Authorization header.
sensitiveLogging suppresses its HTTP request/response/error logs, including
debug logs. Success-payload decoding does not dump recovery data into parse
diagnostics. Other endpoints' authentication/logging behavior is unchanged.

## Created files

- domain/usecases/forgot_password_use_case.dart
- presentation/bloc/forgot_password_cubit.dart
- ../../../test/forgot_password_test.dart (project-root test directory)
- FORGOT_PASSWORD.md

## Modified files (project-relative)

- lib/core/di/injection.dart
- lib/core/network/api_endpoints.dart
- lib/core/network/cap/api_request_context.dart
- lib/core/network/cap/cap_device_app_info.dart
- lib/core/network/interceptors/auth_interceptor.dart
- lib/core/network/interceptors/logging_interceptor.dart
- lib/features/authentication/data/api/auth_api_service.dart
- lib/features/authentication/data/api/auth_api_service.g.dart (Retrofit-generated)
- lib/features/authentication/data/models/auth_models.dart
- lib/features/authentication/data/repositories/auth_repository_impl.dart
- lib/features/authentication/domain/repositories/auth_repository.dart
- lib/screens/auth/auth_screens.dart
- test/biometric_resume_lock_test.dart (explicit test settings, independent of
  the user's production feature toggle; production biometric config untouched)

The auth scaffold's header and Remember Me label now flex at large font scales;
no Login/token-refresh/biometric business logic was changed.

## Verification and backend dependencies

The dedicated tests exercise exact public envelopes, CAP business failures,
false/missing emailSent, invalid expiry/payloads, no token, expired session,
401/500, timeouts, network failure/retry, rapid taps, disposal, log privacy,
installation ID persistence and Arabic/English navigation at 320px / 1.8× text.
Related Login/refresh/session/biometric and CAP-envelope/DI tests are also run.

Verification: 101 authentication/UI/regression tests plus 22 shared CAP/DI/list
tests passed (123 total). Formatting and analysis of changed code are clean.
Full-project flutter analyze still reports 21 pre-existing warnings/info in the
periodic-photo repository and temporary test files; no new errors were added.

Tests use an in-memory HTTP adapter, not a real email request. A live smoke test
needs a backend user with a registered email and functioning email delivery.
No new backend endpoint beyond the supplied contract is required.
