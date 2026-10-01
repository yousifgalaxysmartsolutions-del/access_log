import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/theme/app_theme.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_details_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_timeline_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_details_bloc.dart';
import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';

import 'support/timeline_fixtures.dart';
import 'package:access_log_plus/widgets/skeleton_shimmer.dart';

const int kRealIncidentId = 7391;
const String kRealIncidentNo = 'INC-2026-07391';

/// Builds the exact payload documented for `GetIncidentRequests`.
const IncidentRequestsData kApiRequests = IncidentRequestsData(
  incidentId: kRealIncidentId,
  incidentNo: kRealIncidentNo,
  items: [
    IncidentRequestItemDto(
      id: 1,
      requestType: IdNameDto(id: 1, name: 'Intervention Request'),
      requestStatus: IdNameDto(id: 2, name: 'Approved'),
      remark: 'test',
      createdDate: '2026-09-05T00:00:00',
      createdBy: IdNameDto(id: 4089, name: 'offline user'),
      lastModifiedBy: IdNameDto(id: 4098, name: 'gsm manager'),
      lastModifiedDate: '2026-09-06T23:37:17.22',
    ),
    IncidentRequestItemDto(
      id: 2,
      requestType: IdNameDto(id: 2, name: 'Renewal Request'),
      requestStatus: IdNameDto(id: 3, name: 'Rejected'),
      remark: 'test',
      createdDate: '2026-09-05T00:00:00',
      createdBy: IdNameDto(id: 4089, name: 'offline user'),
      lastModifiedBy: IdNameDto(id: 4098, name: 'gsm manager'),
      lastModifiedDate: '2026-09-07T01:33:42.047',
    ),
  ],
);

const IncidentDetailsData kApiDetails = IncidentDetailsData(
  id: kRealIncidentId,
  incidentNo: kRealIncidentNo,
  title: 'General payload that must survive',
  productName: 'GENERAL-PRODUCT',
  createdDate: '2026-08-02T16:10:00',
);

class _FakeIncidentDetailsRepository implements IncidentDetailsRepository {
  int detailsCalls = 0;
  int timelineCalls = 0;
  int requestsCalls = 0;
  final List<int> requestsIds = [];

  Result<IncidentDetailsData> detailsResult = const Success(kApiDetails);
  Result<IncidentRequestsData> requestsResult = const Success(kApiRequests);

  /// Never completed by default, so a test can hold a request in flight.
  Completer<void>? gate;

  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    detailsCalls++;
    await gate?.future;
    return detailsResult;
  }

  @override
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  }) async {
    timelineCalls++;
    return const Success(kEmptyTimelineData);
  }

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    requestsCalls++;
    requestsIds.add(incidentId);
    await gate?.future;
    return requestsResult;
  }
}

final DateTime _fixedIncidentDate = DateTime(2026, 9, 5);

CapIncident buildIncident() => CapIncident(
  incidentId: kRealIncidentId,
  number: kRealIncidentNo,
  type: 'Transmission',
  siteName: 'North Tower',
  siteCode: 'SITE-CODE-1',
  region: 'Cairo',
  area: 'Maadi',
  location: 'Location',
  title: 'CapIncident title that must not be used',
  description: 'Description From Screen',
  productName: 'Product From Screen',
  nativeMoName: 'NativeMO From Screen',
  notificationType: 'Notification From Screen',
  priority: Priority.high,
  dateTime: _fixedIncidentDate,
  status: CapIncidentStatus.pending,
  currentUser: 'Assigned From Screen',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeIncidentDetailsRepository repository;
  late IncidentDetailsBloc bloc;

  setUp(() async {
    await services.reset();
    repository = _FakeIncidentDetailsRepository();
  });

  tearDown(() async {
    await services.reset();
  });

  Widget testApp(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: home,
  );

  /// Builds the bloc inside the testWidgets zone.
  ///
  /// `setUp` runs outside the fake-async zone the binding installs, so a bloc
  /// created there schedules its event continuations on the real event loop,
  /// which `tester.pump()` can never flush. Inside the test body those
  /// microtasks belong to the fake-async zone and resolve normally.
  Future<void> pumpScreen(WidgetTester tester, {CapIncident? incident}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bloc = IncidentDetailsBloc(
      getIncidentDetails: GetIncidentDetailsUseCase(repository),
      getIncidentTimeline: GetIncidentTimelineUseCase(repository),
      getIncidentRequests: GetIncidentRequestsUseCase(repository),
    );
    services.registerSingleton<IncidentDetailsBloc>(bloc);

    await tester.pumpWidget(
      testApp(IncidentDetailsScreen(incident: incident ?? buildIncident())),
    );
  }

  /// Advances a fixed number of frames.
  ///
  /// `pumpAndSettle` cannot be used while a shimmer placeholder is on screen
  /// because its controller repeats forever.
  Future<void> settle(
    WidgetTester tester, {
    int frames = 20,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  }

  Future<void> scrollTabDown(WidgetTester tester, {double dy = -400}) async {
    await tester.drag(find.byType(ListView).first, Offset(0, dy));
    await settle(tester, frames: 6);
  }

  /// The scrollable TabBar pushes labels off screen as tabs are selected, so a
  /// label has to be brought back into view before it can be tapped.
  Future<void> tapTab(WidgetTester tester, String label) async {
    // Scoped to the TabBar because the Related Requests panel repeats the same
    // label as its own title.
    final finder = find.descendant(
      of: find.byType(TabBar),
      matching: find.text(label),
    );
    await tester.ensureVisible(finder);
    await settle(tester, frames: 4);
    await tester.tap(finder);
  }

  group('1-2. dispatch on selection', () {
    testWidgets('General alone issues no Related Requests request', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      expect(repository.requestsCalls, 0);
      expect(repository.timelineCalls, 0);
      // The tab is still unbuilt, so nothing of it is on screen yet.
      expect(find.text('Request ID: 1'), findsNothing);
    });

    testWidgets('selecting Related Requests dispatches the real incident id', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(repository.requestsCalls, 1);
      expect(repository.requestsIds, [kRealIncidentId]);
      // One deliberate selection is exactly one request.
      expect(repository.detailsCalls, 1);
    });

    testWidgets('Timeline never dispatches a Related Requests request', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      // Sprint 5C wires Timeline, so it issues its own request and only its own.
      expect(repository.requestsCalls, 0);
      expect(repository.timelineCalls, 1);
    });
  });

  group('3. re-selection', () {
    testWidgets('re-tapping the selected tab requests again, once per tap', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 1);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 2);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 3);
      expect(repository.requestsIds, [
        kRealIncidentId,
        kRealIncidentId,
        kRealIncidentId,
      ]);
    });

    testWidgets('leaving and returning requests again', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 1);

      await tapTab(tester, 'General');
      await settle(tester);
      expect(repository.requestsCalls, 1);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 2);
    });

    testWidgets('swiping back to the tab requests again', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 1);

      // Swipe forward twice to reach Related Requests.
      await tester.fling(find.byType(TabBarView), const Offset(-350, 0), 900);
      await settle(tester);
      await tester.fling(find.byType(TabBarView), const Offset(-350, 0), 900);
      await settle(tester);
      expect(repository.requestsCalls, 1);
      expect(repository.requestsIds, [kRealIncidentId]);

      // Swipe away from it: neither neighbouring tab loads requests.
      await tester.fling(find.byType(TabBarView), const Offset(350, 0), 900);
      await settle(tester);
      expect(repository.requestsCalls, 1);

      // Swipe back into it.
      await tester.fling(find.byType(TabBarView), const Offset(-350, 0), 900);
      await settle(tester);
      expect(repository.requestsCalls, 2);
      expect(repository.requestsIds, [kRealIncidentId, kRealIncidentId]);
    });
  });

  group('4. first load', () {
    testWidgets('loading with no data shows an inline skeleton', (
      tester,
    ) async {
      // Never completes, so the tab stays in its first-load state.
      repository.gate = Completer<void>();
      await pumpScreen(tester);
      await settle(tester);

      // The gate is never completed, so settling fully still leaves the tab in
      // its first-load state.
      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(repository.requestsCalls, 1);
      expect(bloc.state.relatedRequestsLoading, isTrue);
      expect(bloc.state.relatedRequestsData, isNull);
      expect(find.byType(SkeletonBox), findsWidgets);

      // The surrounding screen stays usable, and no full-screen loader appears.
      expect(find.text('Incident Details'), findsOneWidget);
      expect(find.text('Related Requests'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });
  });

  group('5. success mapping', () {
    testWidgets('renders the real API values', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.byType(SkeletonBox), findsNothing);
      // Type names come from the API, never from a guessed enum.
      // Twice each: the group header and the card's own Type row.
      expect(find.text('Intervention Request'), findsNWidgets(2));
      expect(find.text('Renewal Request'), findsNWidgets(2));
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('offline user'), findsNWidgets(2));
      expect(find.text('gsm manager'), findsNWidgets(2));
      expect(find.text('Request ID: 1'), findsOneWidget);
      expect(find.text('Request ID: 2'), findsOneWidget);
    });

    testWidgets('does not render a fabricated request number', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.textContaining('REQ-'), findsNothing);
      expect(find.textContaining('#1'), findsNothing);
      expect(find.text('REQUEST-2'), findsNothing);
    });

    testWidgets('formats API dates with the shared formatter', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      await scrollTabDown(tester);

      // 2026-09-05T00:00:00 rendered as dd/MM/yyyy, not the old hardcoded form.
      expect(find.textContaining('05/09/2026'), findsWidgets);
      expect(find.textContaining('Aug 2026'), findsNothing);
    });

    testWidgets('shows the remark and last-modified fields', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      await scrollTabDown(tester);

      expect(find.text('Remark: '), findsWidgets);
      expect(find.text('Last Modified By: '), findsWidgets);
      expect(find.text('Last Modified Date: '), findsWidgets);
      expect(find.textContaining('06/09/2026'), findsWidgets);
    });
  });

  group('6. empty state', () {
    testWidgets('an empty items list is a success, not an error', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(incidentId: 26),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(bloc.state.relatedRequestsFailure, isNull);
      expect(find.text('No related requests'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(SkeletonBox), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null items list also renders the empty state', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(incidentId: kRealIncidentId),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('No related requests'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('7. error and retry', () {
    testWidgets('a failure with no data shows an inline error', (tester) async {
      repository.requestsResult = const FailureResult(
        ServerFailure('Service unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('Incident Details'), findsOneWidget);
    });

    testWidgets('Retry dispatches Related Requests only', (tester) async {
      repository.requestsResult = const FailureResult(
        ServerFailure('Service unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(repository.requestsCalls, 1);

      repository.requestsResult = const Success(kApiRequests);
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(repository.requestsCalls, 2);
      expect(repository.requestsIds, [kRealIncidentId, kRealIncidentId]);
      // The other two panels are untouched.
      expect(repository.detailsCalls, 1);
      expect(repository.timelineCalls, 0);
      expect(find.text('Request ID: 1'), findsOneWidget);
    });
  });

  group('8-9. refresh', () {
    testWidgets('existing requests stay visible while refreshing', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(find.text('Request ID: 1'), findsOneWidget);

      repository.gate = Completer<void>();
      await tapTab(tester, 'Related Requests');
      await tester.pump();
      await tester.pump();

      expect(bloc.state.relatedRequestsLoading, isTrue);
      expect(bloc.state.relatedRequestsData, isNotNull);
      expect(find.text('Request ID: 1'), findsOneWidget);
      expect(find.text('Request ID: 2'), findsOneWidget);
      expect(find.text('Refreshing…'), findsOneWidget);
      // The full skeleton must not replace existing content.
      expect(find.byType(SkeletonBox), findsNothing);
    });

    testWidgets('a failure during refresh keeps the last list visible', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      repository.requestsResult = const FailureResult(
        NetworkFailure('Network unavailable'),
      );
      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(bloc.state.relatedRequestsFailure, isNotNull);
      expect(find.text('Network unavailable'), findsOneWidget);
      expect(find.text('Request ID: 1'), findsOneWidget);
      expect(find.text('Request ID: 2'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
    });
  });

  group('10-12. resilience and source of truth', () {
    testWidgets('null optional values render as dashes, never "null"', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(
          incidentId: kRealIncidentId,
          items: [IncidentRequestItemDto(id: 9)],
        ),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Request ID: 9'), findsOneWidget);
      expect(find.text('-'), findsWidgets);
      expect(find.textContaining('null', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown type and status are shown, not dropped', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(
          incidentId: kRealIncidentId,
          items: [
            IncidentRequestItemDto(
              id: 3,
              requestType: IdNameDto(id: 99, name: 'Escalation Request'),
              requestStatus: IdNameDto(id: 98, name: 'Under Review'),
              createdBy: IdNameDto(id: 1, name: 'unknown user'),
            ),
          ],
        ),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Request ID: 3'), findsOneWidget);
      // Group header plus the card's Type row.
      expect(find.text('Escalation Request'), findsNWidgets(2));
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('unknown user'), findsOneWidget);
    });

    testWidgets('a null request type still renders the request', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(
          incidentId: kRealIncidentId,
          items: [
            IncidentRequestItemDto(
              id: 4,
              requestStatus: IdNameDto(id: 2, name: 'Approved'),
            ),
          ],
        ),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Request ID: 4'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MockData.relatedRequests does not populate the tab', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(incidentId: kRealIncidentId, items: []),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      // The prototype list is seeded from MockData; none of it may appear.
      for (final prototype in MockData.relatedRequests) {
        expect(find.text(prototype.number), findsNothing);
        expect(find.text(prototype.createdBy), findsNothing);
      }
      expect(find.text('No related requests'), findsOneWidget);
    });
  });

  group('13. General is preserved', () {
    testWidgets('General data survives a Related Requests success', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(find.text('General payload that must survive'), findsOneWidget);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(bloc.state.generalData, isNotNull);
      expect(bloc.state.generalFailure, isNull);
      // Exactly one General request: selecting another tab must not reload it.
      expect(repository.detailsCalls, 1);

      await tapTab(tester, 'General');
      await settle(tester);
      expect(find.text('General payload that must survive'), findsOneWidget);
    });

    testWidgets('a Related Requests failure leaves General untouched', (
      tester,
    ) async {
      repository.requestsResult = const FailureResult(
        ServerFailure('Service unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      expect(find.text('Service unavailable'), findsOneWidget);

      expect(bloc.state.generalFailure, isNull);
      expect(bloc.state.generalData, isNotNull);
      expect(repository.detailsCalls, 1);

      await tapTab(tester, 'General');
      await settle(tester);
      // No General skeleton and no General error took over.
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('General payload that must survive'), findsOneWidget);
      expect(find.text('Service unavailable'), findsNothing);
    });
  });

  group('14. pending integrations', () {
    testWidgets('no card navigates to a fabricated request details screen', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Request ID: 1'), findsOneWidget);
      // Tap where the card body is: navigation is disabled until a real
      // GetRequestDetails API exists.
      await tester.tap(find.text('Request ID: 1'));
      await settle(tester);

      expect(find.text('Related Requests'), findsWidgets);
      expect(find.text('Request ID: 1'), findsOneWidget);
      expect(find.textContaining('Questionnaire'), findsNothing);
      expect(repository.requestsCalls, 1);
    });

    testWidgets('no Approve or Reject control mutates API-backed data', (
      tester,
    ) async {
      repository.requestsResult = const Success(
        IncidentRequestsData(
          incidentId: kRealIncidentId,
          items: [
            IncidentRequestItemDto(
              id: 1,
              requestType: IdNameDto(id: 1, name: 'Intervention Request'),
              requestStatus: IdNameDto(id: 1, name: 'Pending Approval'),
            ),
          ],
        ),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });
  });

  group('bloc lifetime', () {
    testWidgets('the screen keeps one bloc across tab changes', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Related Requests');
      await settle(tester);
      await tapTab(tester, 'General');
      await settle(tester);
      await tapTab(tester, 'Related Requests');
      await settle(tester);

      expect(repository.requestsCalls, 2);
      expect(bloc.isClosed, isFalse);

      await tester.pumpWidget(testApp(const SizedBox()));
      await settle(tester);
      expect(bloc.isClosed, isTrue);
    });
  });
}
