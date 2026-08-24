import 'package:access_log_plus/app.dart';
import 'package:access_log_plus/core/routes/app_routes.dart';
import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/screens/auth/auth_screens.dart';
import 'package:access_log_plus/widgets/session_timeout_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    onGenerateRoute: AppRoutes.onGenerateRoute,
    home: home,
  );

  Future<void> phone(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  test('session configuration remains centralized', () {
    expect(MockData.sessionTimeoutMinutes, 30);
    expect(MockData.sessionWarningSeconds, 60);
  });

  testWidgets('warning counts down and Stay Logged In closes it', (
    tester,
  ) async {
    await phone(tester, scale: 1.4);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showSessionExpirationWarning(context, initialSeconds: 60),
                child: const Text('Open warning'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open warning'));
    await tester.pump();
    expect(find.text('Session Expiring Soon'), findsOneWidget);
    expect(find.text('00:60'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:59'), findsOneWidget);
    await tester.ensureVisible(find.text('Stay Logged In'));
    await tester.tap(find.text('Stay Logged In'));
    await tester.pumpAndSettle();
    expect(find.text('Session Expiring Soon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mock countdown expiry shows blocking expired dialog', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showSessionExpirationWarning(context, initialSeconds: 1),
              child: const Text('Expire'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Expire'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Session Expired'), findsOneWidget);
    expect(find.text('Login Again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login Again removes authenticated navigation history', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(const AccessLogApp());
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    final loginContext = tester.element(find.byType(LoginScreen));
    Navigator.push(
      loginContext,
      MaterialPageRoute(builder: (_) => const SessionExpiredScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login Again'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('active intervention logout supports cancel and secure logout', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(const AccessLogApp());
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    final loginContext = tester.element(find.byType(LoginScreen));

    Future<void> openLogout() async {
      final confirmed = await showActiveInterventionLogoutWarning(loginContext);
      if (confirmed && loginContext.mounted) {
        navigateToSecureLogin(loginContext);
      }
    }

    final firstDialog = openLogout();
    await tester.pumpAndSettle();
    expect(find.text('Active Intervention'), findsOneWidget);
    expect(
      find.textContaining(MockData.capIncidents.first.number),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await firstDialog;
    expect(find.byType(LoginScreen), findsOneWidget);

    final secondDialog = openLogout();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Logout'));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await secondDialog;
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic warning remains RTL on a small phone', (tester) async {
    await phone(tester, scale: 1.5);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showSessionExpirationWarning(context),
              child: const Text('فتح'),
            ),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pump();
    expect(find.text('ستنتهي الجلسة قريبًا'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    await tester.ensureVisible(find.text('البقاء مسجلًا'));
    await tester.tap(find.text('البقاء مسجلًا'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
