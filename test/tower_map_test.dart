import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/screens/map/tower_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: home,
  );

  Future<void> phone(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  test('central tower catalogue covers every incident site', () {
    final towerCodes = MockData.towerSites.map((tower) => tower.code).toSet();
    final incidentCodes = MockData.capIncidents
        .map((incident) => incident.siteCode)
        .toSet();
    expect(MockData.towerSites, hasLength(12));
    expect(towerCodes, containsAll(incidentCodes));
  });

  testWidgets('tower marker opens preview and all tower requests', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(app(const TowerMapScreen(enableTiles: false)));
    await tester.pumpAndSettle();

    expect(find.text('Tower Map'), findsOneWidget);
    expect(find.text('12 towers visible'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tower-CAI-CORE-014')));
    await tester.pumpAndSettle();
    expect(find.text('Cairo Central Site'), findsOneWidget);
    expect(find.text('Open All Tower Requests'), findsOneWidget);

    await tester.tap(find.text('Open All Tower Requests'));
    await tester.pumpAndSettle();
    expect(find.byType(TowerRequestsScreen), findsOneWidget);
    expect(find.text('Incidents (1)'), findsOneWidget);
    expect(find.text('Requests (2)'), findsOneWidget);

    await tester.tap(find.text('INC-2026-1001'));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tower list supports local search and empty state', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(app(const TowerMapScreen(enableTiles: false)));
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo Central Site'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not-a-real-tower');
    await tester.pumpAndSettle();
    expect(find.text('No towers found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic tower list handles large text without overflow', (
    tester,
  ) async {
    await phone(tester, scale: 1.4);
    await tester.pumpWidget(
      app(const TowerMapScreen(enableTiles: false), locale: const Locale('ar')),
    );
    await tester.tap(find.byTooltip('عرض القائمة'));
    await tester.pumpAndSettle();

    expect(find.text('خريطة الأبراج'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
