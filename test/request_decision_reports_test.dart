import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
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

  testWidgets('request card supports local approval and rejection decisions', (
    tester,
  ) async {
    await phone(tester);
    final original = List<MyRequest>.of(MockData.myRequests);
    addTearDown(() {
      MockData.myRequests
        ..clear()
        ..addAll(original);
    });
    await tester.pumpWidget(app(const Scaffold(body: MyRequestsScreen())));

    final pendingCard = find.ancestor(
      of: find.text('REN-2026-0021'),
      matching: find.byType(RequestCard),
    );
    final approve = find.descendant(
      of: pendingCard,
      matching: find.text('Approve'),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(approve);
    await tester.pump();

    final updated = tester.widget<RequestCard>(pendingCard).request;
    expect(updated.status, MyRequestStatus.approved);
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
