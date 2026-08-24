import 'package:access_log_plus/app.dart';
import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/incidents/incident_action_flows.dart';
import 'package:access_log_plus/screens/incidents/active_intervention_screen.dart';
import 'package:access_log_plus/screens/component_showcase/prototype_demo_screen.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/screens/incidents/new_request_flows.dart';
import 'package:access_log_plus/screens/more/more_screens.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'package:access_log_plus/widgets/cap_incident_card.dart';
import 'package:access_log_plus/widgets/dynamic_questionnaire.dart';
import 'package:access_log_plus/widgets/evidence_collection.dart';
import 'package:access_log_plus/widgets/location_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget testApp(Widget home, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        home: home,
      );

  testWidgets('critical English flow reaches incident details and filter', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const AccessLogApp());

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('CAP Dashboard'), findsOneWidget);

    await tester.tap(find.text('Total Incidents'));
    await tester.pumpAndSettle();
    expect(find.text('Today’s Incidents'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter incidents'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CapIncidentCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Incident Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic RTL and dark mode switch are functional', (tester) async {
    await setPhoneSize(tester, const Size(360, 800));
    await tester.pumpWidget(const AccessLogApp());
    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(direction.textDirection, TextDirection.rtl);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status-driven incident actions render on Android size', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(412, 915));
    await tester.pumpWidget(
      testApp(IncidentDetailsScreen(incident: MockData.capIncidents.first)),
    );
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('New Renewal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incident workflow exposes the configured actions per status', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(412, 915));

    Future<void> show(CapIncidentStatus status) async {
      final incident = MockData.capIncidents.firstWhere(
        (item) => item.status == status,
      );
      await tester.pumpWidget(
        testApp(
          IncidentDetailsScreen(key: ValueKey(status), incident: incident),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await show(CapIncidentStatus.needAssign);
    expect(find.text('Assign'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await show(CapIncidentStatus.needApproval);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await show(CapIncidentStatus.pending);
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('New Entry Request'), findsOneWidget);

    await show(CapIncidentStatus.inProcess);
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('New Renewal'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);

    await show(CapIncidentStatus.hold);
    expect(find.text('Resume Activity'), findsOneWidget);

    await show(CapIncidentStatus.completed);
    expect(find.text('New Departure Request'), findsOneWidget);

    await show(CapIncidentStatus.cancelled);
    expect(find.textContaining('Incident cancelled'), findsOneWidget);
  });

  testWidgets('all wizard entry screens render without overflow', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    final incident = MockData.capIncidents.first;
    final screens = <Widget>[
      AssignTaskFlow(incident: incident),
      AcceptIncidentFlow(incident: incident),
      RejectIncidentFlow(incident: incident),
      FieldTaskWizard(incident: incident, type: TaskFlowType.start),
      FieldTaskWizard(incident: incident, type: TaskFlowType.hold),
      FieldTaskWizard(incident: incident, type: TaskFlowType.complete),
      NewRequestTypeScreen(incident: incident),
      const NotificationCenterScreen(),
      const ProfileScreen(),
      const ChangeLanguageScreen(),
      const RegisteredDeviceScreen(),
      const Scaffold(body: MyRequestsScreen()),
    ];
    for (var index = 0; index < screens.length; index++) {
      final screen = screens[index];
      await tester.pumpWidget(testApp(screen));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${screen.runtimeType} at index $index',
      );
    }
  });

  testWidgets('shared questionnaire supports conditional fields', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: DynamicQuestionnaireView(
              preset: QuestionnairePreset.complete,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Describe the damage *'), findsNothing);
    await tester.ensureVisible(find.text('Yes').last);
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();
    expect(find.text('Describe the damage *'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue').last);
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();
    expect(find.text('Equipment Status'), findsOneWidget);
    expect(find.text('Incident Number • Read-only'), findsOneWidget);
    expect(find.text('Resolution duration • Disabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mock camera returns accepted photo to collection', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: MockPhotoPicker(title: 'Required Photos'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add Photo'));
    await tester.pumpAndSettle();
    expect(find.text('CAMERA PREVIEW'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Capture photo'));
    await tester.pumpAndSettle();
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Use Photo'), findsOneWidget);
    await tester.tap(find.text('Use Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo metadata'), findsOneWidget);
    expect(find.textContaining('INT-260811-0064'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attachment and signature states render', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [AttachmentPickerView(), SignaturePadView()],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('Uploading'), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
    await tester.ensureVisible(find.text('Tap canvas to draw mock signature'));
    await tester.tap(find.text('Tap canvas to draw mock signature'));
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm Signature'));
    await tester.tap(find.text('Confirm Signature'));
    await tester.pumpAndSettle();
    expect(find.text('Signature Captured'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location validation exposes all mock outcomes', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      testApp(
        const LocationValidationScreen(
          initialState: LocationCheckState.outside,
        ),
      ),
    );

    expect(find.text('Outside Permitted Area'), findsOneWidget);
    expect(find.text('265 meters'), findsOneWidget);
    expect(find.text('Retry Location'), findsOneWidget);
    await tester.ensureVisible(find.text('Unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Location Unavailable'), findsOneWidget);
    expect(find.text('GPS disabled'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checking location resolves to verified mock state', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(testApp(const LocationValidationScreen()));
    expect(find.text('Checking your location…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Location Verified'), findsOneWidget);
    expect(find.text('42 meters'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active intervention renders and opens existing hold flow', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    final incident = MockData.capIncidents.first;
    await tester.pumpWidget(
      testApp(ActiveInterventionScreen(incident: incident)),
    );

    expect(find.text('INC-2026-1001'), findsOneWidget);
    expect(find.text('01:42:18'), findsWidgets);
    expect(find.text('Inside Geofence'), findsOneWidget);
    expect(find.text('Capture Verification Photo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hold Task'), 300);
    await tester.tap(find.text('Hold Task'));
    await tester.pumpAndSettle();
    expect(find.text('Hold Reason'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden prototype demo opens previews', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(testApp(const PrototypeDemoScreen()));

    expect(find.text('Prototype Demo'), findsOneWidget);
    expect(find.text('AUTHENTICATION STATES'), findsOneWidget);
    expect(find.text('Normal Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app logo long press opens hidden demo route', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const AccessLogApp());
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('+'));
    await tester.pumpAndSettle();
    expect(find.text('Prototype Demo'), findsOneWidget);
    await tester.ensureVisible(find.text('Invalid Credentials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invalid Credentials'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic product flow stays RTL through core screens', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const AccessLogApp());
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة تحكم CAP'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    await tester.tap(find.text('إجمالي البلاغات'));
    await tester.pumpAndSettle();
    expect(find.text('بلاغات اليوم'), findsOneWidget);
    expect(find.text('خرج وحدة التقويم أقل من الحد المسموح'), findsOneWidget);
    await tester.tap(find.byType(CapIncidentCard).first);
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل البلاغ'), findsOneWidget);
    await tester.tap(find.text('الخط الزمني'));
    await tester.pumpAndSettle();
    expect(find.text('دورة حياة البلاغ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Arabic form labels fit with enlarged text', (tester) async {
    await setPhoneSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      testApp(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(14),
              child: DynamicQuestionnaireView(
                preset: QuestionnairePreset.intervention,
              ),
            ),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('نموذج التدخل'), findsOneWidget);
    expect(find.text('هل تضررت أي معدات؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic requests notifications and profile render cleanly', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(360, 800));
    final screens = <Widget>[
      const Scaffold(body: MyRequestsScreen()),
      const NotificationCenterScreen(),
      const ProfileScreen(),
      IncidentDetailsScreen(incident: MockData.capIncidents.first),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(testApp(screen, locale: const Locale('ar')));
      await tester.pump();
      expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
  });

  testWidgets('More language toggle updates RTL and LTR immediately', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(const AccessLogApp());
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('اللغة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Change Language'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.ltr,
    );
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('تغيير اللغة'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
