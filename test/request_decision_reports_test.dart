import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/screens/reporting/reporting_screen.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import 'engineer_locations_report_test.dart'
    show EngineerReportTestRepository, engineerReportTestCubit;
import 'package:access_log_plus/features/reports/presentation/bloc/requests_path_report_cubit.dart';
import 'package:access_log_plus/features/requests/presentation/bloc/request_details_cubit.dart';
import 'requests_path_report_test.dart'
    show PathReportTestRepository, pathReportTestCubit;
import 'request_details_test.dart' show RequestDetailsTestCubit;

void main() {
  Widget app(Widget home) => MaterialApp(
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

  testWidgets('API request card is read-only without prototype navigation', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        const Scaffold(body: RequestCard(request: RequestListItemDto(id: 3))),
      ),
    );
    expect(find.text('Request #3'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    await tester.tap(find.text('Request #3'));
    await tester.pump();
    expect(find.byType(RequestDetailsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request flow report opens request details', (tester) async {
    await services.reset();
    addTearDown(services.reset);
    services.registerFactory<RequestsPathReportCubit>(
      () => pathReportTestCubit(PathReportTestRepository()),
    );
    services.registerFactory<RequestDetailsCubit>(
      () => RequestDetailsTestCubit(),
    );
    await phone(tester);
    await tester.pumpWidget(app(const RequestFlowReportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Request Lifecycles'), findsOneWidget);
    expect(find.text('Created'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('INT-2026-0003'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('INT-2026-0003'));
    await tester.pumpAndSettle();
    expect(find.text('Request Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engineer sites report summarizes worked locations', (
    tester,
  ) async {
    await services.reset();
    addTearDown(services.reset);
    services.registerFactory<EngineerLocationsReportCubit>(
      () => engineerReportTestCubit(EngineerReportTestRepository()),
    );
    await phone(tester);
    await tester.pumpWidget(app(const EngineerSitesReportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Worked Sites'), findsOneWidget);
    expect(find.text('engineer 1'), findsOneWidget);
    expect(find.byIcon(Icons.cell_tower), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
