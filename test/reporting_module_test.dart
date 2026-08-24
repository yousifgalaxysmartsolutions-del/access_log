import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/screens/reporting/reporting_screen.dart';
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

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('reporting filters use centralized incident catalogue', () {
    const month = ReportingFilter(range: ReportRange.month);
    expect(
      applyReportingFilter(MockData.capIncidents, month),
      hasLength(MockData.capIncidents.length),
    );
    expect(
      applyReportingFilter(
        MockData.capIncidents,
        month.copyWith(status: CapIncidentStatus.completed),
      ).every((item) => item.status == CapIncidentStatus.completed),
      isTrue,
    );
    expect(
      applyReportingFilter(
        MockData.capIncidents,
        month.copyWith(region: 'Unknown Region'),
      ),
      isEmpty,
    );
    final employee = MockData.teamMembers.first.name;
    expect(
      applyReportingFilter(
        MockData.capIncidents,
        month.copyWith(employee: employee),
      ).every((item) => item.currentUser == employee),
      isTrue,
    );
  });

  testWidgets('reporting home opens all three report types', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const Scaffold(body: ReportingScreen())));

    expect(find.text('Report Types'), findsOneWidget);
    expect(find.text('Incident Report'), findsOneWidget);
    expect(find.text('Engineer Activity Report'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Site Activity Report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Site Activity Report'), findsOneWidget);

    await tester.ensureVisible(find.text('Incident Report'));
    await tester.tap(find.text('Incident Report'));
    await tester.pumpAndSettle();
    expect(find.text('Incidents by Status'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Incidents by Priority'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Incidents by Priority'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Engineer Activity Report'));
    await tester.tap(find.text('Engineer Activity Report'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmed Mohamed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI and report records deep-link to details', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        const IncidentReportScreen(
          initialFilter: ReportingFilter(range: ReportRange.month),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Completed').first);
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('detailed records'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('INC-2026-1005'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('INC-2026-1005'));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each engineer report filters its records by worked site', (
    tester,
  ) async {
    await phone(tester);
    final member = MockData.teamMembers.first;
    final assigned = MockData.capIncidents
        .where((item) => item.currentUser == member.name)
        .toList();
    await tester.pumpWidget(
      app(
        EngineerReportDetailsScreen(
          member: member,
          incidents: assigned,
          filter: const ReportingFilter(range: ReportRange.month),
        ),
      ),
    );

    expect(find.text('Filter by Site'), findsOneWidget);
    expect(find.text('${assigned.length} sites available'), findsOneWidget);
    await tester.tap(find.text('All Sites'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('CAI-HUB-005').last);
    await tester.pumpAndSettle();
    expect(find.text('Shubra Hub 05'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Arabic reporting and filter sheet remain RTL and overflow-free',
    (tester) async {
      await phone(tester);
      await tester.pumpWidget(
        app(
          const IncidentReportScreen(
            initialFilter: ReportingFilter(range: ReportRange.month),
          ),
          locale: const Locale('ar'),
        ),
      );

      expect(find.text('تقرير البلاغات'), findsOneWidget);
      expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
        TextDirection.rtl,
      );
      await tester.tap(find.byTooltip('الفلاتر'));
      await tester.pumpAndSettle();
      expect(find.text('فلاتر التقارير'), findsOneWidget);
      expect(find.text('من تاريخ'), findsNothing);
      await tester.tap(find.text('مخصص').last);
      await tester.pumpAndSettle();
      expect(find.text('من تاريخ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
