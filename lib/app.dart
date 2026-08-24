import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

class AccessLogApp extends StatefulWidget {
  const AccessLogApp({super.key});
  static AccessLogAppState of(BuildContext context) =>
      context.findAncestorStateOfType<AccessLogAppState>()!;
  @override
  State<AccessLogApp> createState() => AccessLogAppState();
}

class AccessLogAppState extends State<AccessLogApp> {
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.light;
  bool get isDark => _themeMode == ThemeMode.dark;
  void toggleLocale() => setState(
    () => _locale = Locale(_locale.languageCode == 'en' ? 'ar' : 'en'),
  );
  void setLocale(Locale locale) => setState(() => _locale = locale);
  void toggleTheme() =>
      setState(() => _themeMode = isDark ? ThemeMode.light : ThemeMode.dark);
  @override
  Widget build(BuildContext context) => MaterialApp(
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
