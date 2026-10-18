import 'package:flutter/material.dart';
import 'dart:async';
import 'core/di/injection.dart';
import 'core/network/cap/cap_locale_holder.dart';
import 'core/session/session_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/gps_tracking/domain/gps_tracking_manager.dart';
import 'features/gps_tracking/domain/gps_tracking_sync_service.dart';

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
        } else {
          if (services.isRegistered<GpsTrackingManager>()) {
            // Session restored/refreshed: reconcile tracking with configuration.
            unawaited(services<GpsTrackingManager>().reconcile());
          }
          // New authenticated session: attempt to upload anything pending.
          _requestGpsSync();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App reopened/foregrounded: a good moment to retry pending uploads.
    if (state == AppLifecycleState.resumed) _requestGpsSync();
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
    );
  }
}
