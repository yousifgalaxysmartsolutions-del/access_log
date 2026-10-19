import 'package:flutter/material.dart';
import 'dart:async';
import 'core/context/active_incident_context.dart';
import 'core/di/injection.dart';
import 'core/network/cap/cap_locale_holder.dart';
import 'core/session/session_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/app_requirements/presentation/app_requirement_guard.dart';
import 'features/gps_tracking/domain/gps_requirement_gate.dart';
import 'features/gps_tracking/domain/gps_tracking_manager.dart';
import 'features/gps_tracking/domain/gps_tracking_sync_service.dart';
import 'features/periodic_photo/domain/periodic_photo_gate.dart';

class AccessLogApp extends StatefulWidget {
  const AccessLogApp({super.key});
  static AccessLogAppState of(BuildContext context) =>
      context.findAncestorStateOfType<AccessLogAppState>()!;
  @override
  State<AccessLogApp> createState() => AccessLogAppState();
}

class AccessLogAppState extends State<AccessLogApp>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<SessionStatus>? _sessionSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (services.isRegistered<SessionManager>()) {
      _sessionSubscription = services<SessionManager>().changes.listen((
        status,
      ) {
        if (status != SessionStatus.authenticated) {
          _navigator.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (_) => false,
          );
          // Stop capture for a signed-out session; the next sign-in reconciles.
          // Local GPS points are never deleted on sign-out.
          if (services.isRegistered<GpsTrackingManager>()) {
            unawaited(services<GpsTrackingManager>().stopTracking());
          }
          // Leaving an incident context must not survive sign-out: a stale
          // IncidentId can never leak into a later periodic-photo upload.
          if (services.isRegistered<ActiveIncidentContext>()) {
            services<ActiveIncidentContext>().clear();
          }
        } else {
          // Session restored/refreshed: the app-level requirements (GPS and
          // periodic photo) must be satisfied again. Both gates reconcile
          // internally.
          _requestRequirementReconcile();
          // New authenticated session: attempt to upload anything pending.
          _requestGpsSync();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // App reopened/foregrounded: re-check the app-level requirements
    // (configuration, permissions, tracker, periodic-photo deadline) and retry
    // pending uploads. An overdue photo shows its ONE blocking gate here —
    // nothing ever opens the camera automatically.
    _requestRequirementReconcile();
    _requestGpsSync();
  }

  void _requestRequirementReconcile() {
    if (services.isRegistered<GpsRequirementGate>()) {
      unawaited(services<GpsRequirementGate>().reconcile());
    }
    if (services.isRegistered<PeriodicPhotoGate>()) {
      unawaited(services<PeriodicPhotoGate>().reconcile());
    }
  }

  void _requestGpsSync() {
    if (services.isRegistered<GpsTrackingSyncService>()) {
      services<GpsTrackingSyncService>().requestSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.light;
  bool get isDark => _themeMode == ThemeMode.dark;
  void toggleLocale() =>
      setLocale(Locale(_locale.languageCode == 'en' ? 'ar' : 'en'));
  void setLocale(Locale locale) => setState(() {
    _locale = locale;
    _syncLocale();
  });
  void toggleTheme() =>
      setState(() => _themeMode = isDark ? ThemeMode.light : ThemeMode.dark);

  /// Lets the CAP data layer pick `resultmessageen`/`resultmessagear` without
  /// needing a `BuildContext`.
  void _syncLocale() => CapLocaleHolder.instance.update(_locale);

  @override
  Widget build(BuildContext context) {
    _syncLocale();
    return MaterialApp(
      navigatorKey: _navigator,
      initialRoute:
          services.isRegistered<SessionManager>() &&
              services<SessionManager>().isAuthenticated
          ? AppRoutes.home
          : AppRoutes.login,
      debugShowCheckedModeBanner: false,
      title: 'Access Log+',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      // One centralized requirement guard for the whole app. It decides — GPS
      // first, then the periodic photo — which single blocking screen (if any)
      // covers the navigator. Presentation-only and inert when a gate's graph
      // is not registered.
      builder: (context, child) =>
          AppRequirementGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
