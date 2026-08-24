import 'package:access_log_plus/app.dart';
import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/screens/incidents/active_intervention_screen.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/screens/incidents/incident_list_screen.dart';
import 'package:access_log_plus/screens/more/more_screens.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'package:access_log_plus/widgets/dynamic_questionnaire.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const phoneSizes = <String, Size>{
  'small Android': Size(320, 568),
  'standard Android': Size(360, 800),
  'large Android': Size(432, 936),
  'small iPhone': Size(375, 667),
  'standard iPhone': Size(390, 844),
  'large iPhone': Size(430, 932),
};

void main() {
  Widget app(Widget child, Locale locale, {double scale = 1}) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  tearDown(() {});

  testWidgets('core screens fit six mobile viewports in LTR and RTL', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final viewport in phoneSizes.entries) {
      await setSize(tester, viewport.value);
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final screens = <Widget>[
          const IncidentListScreen(),
          IncidentDetailsScreen(incident: MockData.capIncidents.first),
          const Scaffold(body: MyRequestsScreen()),
          ActiveInterventionScreen(incident: MockData.capIncidents.first),
          const NotificationCenterScreen(),
          const ProfileScreen(),
        ];
        for (final screen in screens) {
          await tester.pumpWidget(app(screen, locale));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason:
                '${viewport.key} ${locale.languageCode} ${screen.runtimeType}',
          );
        }
      }
    }
  });

  testWidgets('large system font scales on smallest and largest phones', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      phoneSizes['small Android']!,
      phoneSizes['large iPhone']!,
    ]) {
      await setSize(tester, size);
      for (final locale in const [Locale('en'), Locale('ar')]) {
        await tester.pumpWidget(
          app(
            const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(12),
                child: DynamicQuestionnaireView(
                  preset: QuestionnairePreset.complete,
                ),
              ),
            ),
            locale,
            scale: 1.5,
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${size.width} ${locale.languageCode} questionnaire',
        );
      }
    }
  });

  testWidgets('interactive controls expose comfortable touch targets', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setSize(tester, phoneSizes['small Android']!);
    await tester.pumpWidget(
      app(const NotificationCenterScreen(), const Locale('en')),
    );
    await tester.pump();
    for (final element in find.byType(IconButton).evaluate()) {
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('login remains scrollable above a small-phone keyboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await setSize(tester, phoneSizes['small Android']!);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpWidget(const AccessLogApp());
    await tester.pump();
    final password = find.byType(TextField).at(1);
    await tester.ensureVisible(password);
    await tester.pump();
    await tester.tap(password);
    await tester.showKeyboard(password);
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
