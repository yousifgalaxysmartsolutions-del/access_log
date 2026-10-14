import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/reporting/reporting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'incident_report_test.dart' show registerReportTestCubit;
import 'engineers_activity_report_test.dart'
    show registerActivityReportTestCubit;

void main() {
  setUp(() async {
    await services.reset();
    registerReportTestCubit();
    registerActivityReportTestCubit();
  });
  tearDown(() => services.reset());
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
    expect(find.text('engineer 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incident report renders API summaries and real report records', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(app(const IncidentReportScreen()));

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('INC-SEED-D10739-04'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Test Incident - D10739'), findsOneWidget);
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
        app(const IncidentReportScreen(), locale: const Locale('ar')),
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
      await tester.tap(find.text('مخصص').last);
      await tester.pumpAndSettle();
      expect(find.text('1/10/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
