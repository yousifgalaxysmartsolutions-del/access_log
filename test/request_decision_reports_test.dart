import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/screens/reporting/reporting_screen.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await phone(tester);
    await tester.pumpWidget(app(const RequestFlowReportScreen()));

    expect(find.text('Request Lifecycles'), findsOneWidget);
    expect(find.text('Created'), findsWidgets);
    await tester.tap(find.text(MockData.myRequests.first.number).first);
    await tester.pumpAndSettle();
    expect(find.text('Request Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engineer sites report summarizes worked locations', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(app(const EngineerSitesReportScreen()));

    expect(find.text('Worked Sites'), findsOneWidget);
    expect(find.text('Ahmed Mohamed'), findsOneWidget);
    expect(find.byIcon(Icons.cell_tower), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
