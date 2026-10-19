import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/gps_requirement_gate.dart';

/// Centralized, app-level enforcement of the GPS requirements.
///
/// Mounted once around the whole `MaterialApp` navigator. For an *authenticated*
/// session it covers the app with a blocking screen whenever the
/// [GpsRequirementGate] is not [GpsGateState.allowsUsage]; signed-out sessions
/// (the login flow) are never blocked.
///
/// It is presentation only: it reads the gate state and forwards one user
/// intent. It never talks to the platform and never owns the requirement logic.
class GpsGateGuard extends StatefulWidget {
  const GpsGateGuard({super.key, required this.child});

  /// The app's navigator/routes.
  final Widget child;

  @override
  State<GpsGateGuard> createState() => _GpsGateGuardState();
}

class _GpsGateGuardState extends State<GpsGateGuard> {
  GpsRequirementGate? _gate;
  SessionManager? _session;
  StreamSubscription<GpsGateState>? _gateSubscription;
  StreamSubscription<SessionStatus>? _sessionSubscription;

  GpsGateState _state = GpsGateState.checking;
  bool _authenticated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _gate = services.isRegistered<GpsRequirementGate>()
        ? services<GpsRequirementGate>()
        : null;
    _session = services.isRegistered<SessionManager>()
        ? services<SessionManager>()
        : null;
    _state = _gate?.state ?? GpsGateState.disabledByConfiguration;
    _authenticated = _session?.isAuthenticated ?? false;

    _gateSubscription = _gate?.changes.listen((value) {
      if (mounted) setState(() => _state = value);
    });
    _sessionSubscription = _session?.changes.listen((status) {
      final authenticated = status == SessionStatus.authenticated;
      if (mounted) setState(() => _authenticated = authenticated);
      // A fresh authenticated session must satisfy the requirements again.
      if (authenticated) unawaited(_gate?.reconcile());
    });
  }

  @override
  void dispose() {
    _gateSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAction() async {
    final gate = _gate;
    if (gate == null || _busy) return;
    setState(() => _busy = true);
    try {
      switch (_state) {
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocking =
        _gate != null && _authenticated && !_state.allowsUsage;
    if (!blocking) return widget.child;
    // The blocking layer sits on top of the (still mounted) navigator, so the
    // route stack is preserved and simply covered and non-interactive.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: _GpsBlockingScreen(
            state: _state,
            busy: _busy,
            onAction: _handleAction,
          ),
        ),
      ],
    );
  }
}

class _GpsBlockingScreen extends StatelessWidget {
  const _GpsBlockingScreen({
    required this.state,
    required this.busy,
    required this.onAction,
  });

  final GpsGateState state;
  final bool busy;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final content = _content(context, state);
    return Material(
      color: AppColors.background,
      child: Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: content.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: content.leading ??
                          Icon(content.icon, size: 46, color: content.color),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (content.action != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: busy ? null : onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(content.actionIcon ?? content.icon),
                        label: Text(content.action!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GateContent _content(BuildContext context, GpsGateState state) =>
      switch (state) {
        GpsGateState.permissionRequired => _GateContent(
          icon: Icons.location_on_outlined,
          color: AppColors.orange,
          title: context.tr(
            'Location Permission Required',
            'صلاحية الموقع مطلوبة',
          ),
          body: context.tr(
            'CAP requires location access for background tracking.',
            'يتطلب CAP الوصول إلى الموقع للتتبع في الخلفية.',
          ),
          action: context.tr('Allow Location', 'السماح بالموقع'),
        ),
        GpsGateState.backgroundPermissionRequired => _GateContent(
          icon: Icons.my_location_rounded,
          color: AppColors.orange,
          title: context.tr(
            'Background Location Required',
            'الموقع في الخلفية مطلوب',
          ),
          body: context.tr(
            'CAP requires background location access while tracking is enabled.',
            'يتطلب CAP الوصول إلى الموقع في الخلفية أثناء تشغيل التتبع.',
          ),
          action: context.tr(
            'Allow Background Location',
            'السماح بالموقع في الخلفية',
          ),
        ),
        GpsGateState.locationServicesDisabled => _GateContent(
          icon: Icons.gps_off_rounded,
          color: AppColors.warning,
          title: context.tr(
            'Location Services Required',
            'خدمة الموقع مطلوبة',
          ),
          body: context.tr(
            'Please enable Location Services to continue using CAP.',
            'يرجى تفعيل خدمة الموقع لمتابعة استخدام CAP.',
          ),
          action: context.tr('Enable Location', 'تفعيل الموقع'),
          actionIcon: Icons.open_in_new_rounded,
        ),
        GpsGateState.error => _GateContent(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: context.tr('Location Unavailable', 'الموقع غير متاح'),
          body: context.tr(
            'CAP could not start location tracking. Check permissions and try again.',
            'تعذّر تشغيل تتبع الموقع. تحقق من الصلاحيات وحاول مجددًا.',
          ),
          action: context.tr('Try Again', 'إعادة المحاولة'),
          actionIcon: Icons.refresh_rounded,
        ),
        GpsGateState.checking || GpsGateState.startingTracker => _GateContent(
          icon: Icons.location_searching_rounded,
          color: AppColors.info,
          title: context.tr('Checking Location…', 'جارٍ التحقق من الموقع…'),
          body: context.tr(
            'CAP is verifying the device location requirements.',
            'يتحقق CAP من متطلبات موقع الجهاز.',
          ),
          leading: const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        GpsGateState.ready || GpsGateState.disabledByConfiguration =>
          _GateContent(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            title: context.tr('Ready', 'جاهز'),
            body: '',
          ),
      };
}

class _GateContent {
  const _GateContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
    this.actionIcon,
    this.leading,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? action;
  final IconData? actionIcon;
  final Widget? leading;
}
