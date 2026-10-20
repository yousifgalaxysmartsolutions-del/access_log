import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/session/session_manager.dart';
import '../../gps_tracking/domain/gps_requirement_gate.dart';
import '../../gps_tracking/presentation/gps_blocking_screen.dart';
import '../../periodic_photo/domain/periodic_photo_gate.dart';
import '../../periodic_photo/presentation/periodic_photo_blocking_screen.dart';

/// Which requirement currently owns the app's single blocking overlay.
enum AppRequirement { none, gps, photo }

/// Confirmed GPS issues are resolved first, then the periodic photo.
/// Routine GPS checks/startup do not require an overlay.
///
/// Extracted as a pure function so "there must never be two competing blocking
/// screens" is directly testable instead of being an accident of widget code.
AppRequirement pickBlockingRequirement({
  required bool authenticated,
  required bool gpsBlocking,
  required bool photoBlocking,
}) {
  if (!authenticated) return AppRequirement.none;
  // GPS invalid → resolve GPS first, even when a photo is also overdue.
  if (gpsBlocking) return AppRequirement.gps;
  if (photoBlocking) return AppRequirement.photo;
  return AppRequirement.none;
}

/// Centralized, app-level enforcement of *all* blocking requirements.
///
/// Mounted once around the whole `MaterialApp` navigator — the app never has a
/// second root overlay, and no screen implements any requirement logic:
///
/// ```text
/// GpsRequirementGate  ─┐
///                      ├─ pickBlockingRequirement (GPS > photo)
/// PeriodicPhotoGate  ──┘            ↓
///                          exactly ONE blocking screen,
///                          on top of the (still mounted) navigator
/// ```
///
/// Signed-out sessions are never blocked (the login flow stays usable), and
/// each gate being unregistered keeps its requirement inert — so existing
/// tests that never build the GPS/photo graphs behave exactly as before.
class AppRequirementGuard extends StatefulWidget {
  const AppRequirementGuard({
    super.key,
    required this.child,
    this.gpsGate,
    this.photoGate,
    this.session,
  });

  /// The app's navigator/routes.
  final Widget child;

  /// Injected for tests; otherwise resolved from DI when registered.
  final GpsRequirementGate? gpsGate;
  final PeriodicPhotoGate? photoGate;
  final SessionManager? session;

  @override
  State<AppRequirementGuard> createState() => _AppRequirementGuardState();
}

class _AppRequirementGuardState extends State<AppRequirementGuard> {
  GpsRequirementGate? _gpsGate;
  PeriodicPhotoGate? _photoGate;
  SessionManager? _session;

  StreamSubscription<GpsGateState>? _gpsSubscription;
  StreamSubscription<PeriodicPhotoGateState>? _photoSubscription;
  StreamSubscription<SessionStatus>? _sessionSubscription;

  GpsGateState _gpsState = GpsGateState.checking;
  PeriodicPhotoGateState _photoState = PeriodicPhotoGateState.checking;
  bool _authenticated = false;
  bool _gpsBusy = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _gpsGate =
        widget.gpsGate ??
        (services.isRegistered<GpsRequirementGate>()
            ? services<GpsRequirementGate>()
            : null);
    _photoGate =
        widget.photoGate ??
        (services.isRegistered<PeriodicPhotoGate>()
            ? services<PeriodicPhotoGate>()
            : null);
    _session =
        widget.session ??
        (services.isRegistered<SessionManager>()
            ? services<SessionManager>()
            : null);

    _gpsState = _gpsGate?.state ?? GpsGateState.disabledByConfiguration;
    _photoState = _photoGate?.state ?? PeriodicPhotoGateState.checking;
    _authenticated = _session?.isAuthenticated ?? false;

    _gpsSubscription = _gpsGate?.changes.listen((value) {
      if (mounted) setState(() => _gpsState = value);
    });
    _photoSubscription = _photoGate?.changes.listen((value) {
      if (mounted) setState(() => _photoState = value);
    });
    _sessionSubscription = _session?.changes.listen((status) {
      final authenticated = status == SessionStatus.authenticated;
      if (mounted) setState(() => _authenticated = authenticated);
      // A fresh authenticated session must satisfy *both* requirements again.
      if (authenticated) _reconcileRequirements();
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _photoSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _reconcileRequirements() {
    if (_gpsGate != null) unawaited(_gpsGate!.reconcile());
    if (_photoGate != null) unawaited(_photoGate!.reconcile());
  }

  Future<void> _handleGpsAction() async {
    final gate = _gpsGate;
    if (gate == null || _gpsBusy) return;
    setState(() => _gpsBusy = true);
    try {
      switch (_gpsState) {
        case GpsGateState.permissionRequired:
        case GpsGateState.backgroundPermissionRequired:
          await gate.requestPermissions();
        case GpsGateState.locationServicesDisabled:
          await gate.openLocationSettings();
        case GpsGateState.checking:
        case GpsGateState.startingTracker:
        case GpsGateState.error:
          await gate.reconcile();
        case GpsGateState.ready:
        case GpsGateState.disabledByConfiguration:
          break;
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  /// Camera capture + upload. The screen only forwards the intent.
  Future<void> _runPhotoIntent(Future<void> Function() intent) async {
    final gate = _photoGate;
    if (gate == null || _photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      await intent();
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requirement = pickBlockingRequirement(
      authenticated: _authenticated,
      gpsBlocking: _gpsGate != null && !_gpsState.allowsUsage,
      photoBlocking: _photoGate != null && !_photoState.allowsUsage,
    );
    final screen = switch (requirement) {
      AppRequirement.none => null,
      AppRequirement.gps => GpsBlockingScreen(
        state: _gpsState,
        busy: _gpsBusy,
        onAction: _handleGpsAction,
      ),
      AppRequirement.photo => PeriodicPhotoBlockingScreen(
        state: _photoState,
        busy: _photoBusy,
        error: _photoGate?.lastError,
        onTakePhoto: () =>
            _runPhotoIntent(() => _photoGate!.captureAndSubmit()),
        onRetry: () => _runPhotoIntent(() => _photoGate!.retryUpload()),
        onRetake: () => _runPhotoIntent(() => _photoGate!.retake()),
      ),
    };
    if (screen == null) return widget.child;
    // The blocking layer sits on top of the (still mounted) navigator, so the
    // route stack is preserved and simply covered and non-interactive. Exactly
    // one layer is ever mounted: requirements never stack.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(child: screen),
      ],
    );
  }
}
