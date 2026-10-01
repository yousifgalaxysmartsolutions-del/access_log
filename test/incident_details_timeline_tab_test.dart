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
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/widgets/skeleton_shimmer.dart';

import 'support/timeline_fixtures.dart';

const int kRealIncidentId = 7391;
const String kRealIncidentNo = 'INC-2026-07391';

const IncidentDetailsData kApiDetails = IncidentDetailsData(
  id: kRealIncidentId,
  incidentNo: kRealIncidentNo,
  title: 'General payload that must survive',
  productName: 'GENERAL-PRODUCT',
  createdDate: '2026-08-02T16:10:00',
);

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
    ),
  ],
);

class _FakeIncidentDetailsRepository implements IncidentDetailsRepository {
  int detailsCalls = 0;
  int timelineCalls = 0;
  int requestsCalls = 0;
  final List<int> timelineIds = [];

  Result<IncidentDetailsData> detailsResult = const Success(kApiDetails);
  Result<IncidentRequestsData> requestsResult = const Success(kApiRequests);

  /// Defaults to a successful response holding an unparsed payload.
  Result<IncidentTimelineData> timelineResult = Success(kTimelineData());

  /// Never completed by default, so a test can hold a request in flight.
  Completer<void>? gate;

  /// Gates only Timeline, so a test can freeze that panel while the other two
  /// still settle.
  Completer<void>? timelineGate;

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
    timelineIds.add(incidentId);
    await timelineGate?.future;
    return timelineResult;
  }

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    requestsCalls++;
    await gate?.future;
    return requestsResult;
  }
}

final DateTime _fixedIncidentDate = DateTime(2026, 9, 5);

CapIncident buildIncident([int incidentId = kRealIncidentId]) => CapIncident(
  incidentId: incidentId,
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

  /// Builds the bloc inside the testWidgets zone.
  ///
  /// `setUp` runs outside the fake-async zone the binding installs, so a bloc
  /// created there schedules its event continuations on the real event loop,
  /// which `tester.pump()` can never flush.
  Future<void> pumpScreen(
    WidgetTester tester, {
    int incidentId = kRealIncidentId,
    Locale locale = const Locale('en'),
  }) async {
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
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        home: IncidentDetailsScreen(incident: buildIncident(incidentId)),
      ),
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

  /// The scrollable TabBar pushes labels off screen as tabs are selected, so a
  /// label has to be brought back into view before it can be tapped.
  Future<void> tapTab(WidgetTester tester, String label) async {
    final finder = find.descendant(
      of: find.byType(TabBar),
      matching: find.text(label),
    );
    await tester.ensureVisible(finder);
    await settle(tester, frames: 4);
    await tester.tap(finder);
  }

  /// The timeline is a lazy ListView, so later cards must be scrolled into view.
  Future<void> scrollTabDown(WidgetTester tester, {double dy = -400}) async {
    await tester.drag(find.byType(ListView).first, Offset(0, dy));
    await settle(tester, frames: 6);
  }

  Future<void> swipeTo(WidgetTester tester, int pages) async {
    for (var i = 0; i < pages; i++) {
      await tester.fling(
        find.byType(TabBarView),
        Offset(-350.0 * pages, 0),
        900.0,
      );
      await settle(tester);
    }
  }

  group('1-2. dispatch on selection', () {
    testWidgets('General alone issues no Timeline request', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      expect(repository.timelineCalls, 0);
    });

    testWidgets('selecting Timeline dispatches the real incident id', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(repository.timelineCalls, 1);
      expect(repository.timelineIds, [kRealIncidentId]);
    });

    testWidgets('one tap issues exactly one request despite onTap + listener', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(repository.timelineCalls, 1);

      // Settling longer must not reveal a late second dispatch.
      await settle(tester, frames: 40);
      expect(repository.timelineCalls, 1);
    });

    testWidgets('Timeline does not trigger the General or requests APIs', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      final generalBefore = repository.detailsCalls;
      final requestsBefore = repository.requestsCalls;

      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(repository.detailsCalls, generalBefore);
      expect(repository.requestsCalls, requestsBefore);
    });
  });

  group('3-4. re-selection and swipe', () {
    testWidgets('re-selecting the Timeline tab dispatches another request', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(repository.timelineCalls, 1);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(repository.timelineCalls, 2);
      expect(repository.timelineIds, [kRealIncidentId, kRealIncidentId]);
    });

    testWidgets('leaving and returning dispatches a fresh request', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(repository.timelineCalls, 1);

      await tapTab(tester, 'General');
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(repository.timelineCalls, 2);
    });

    testWidgets('swiping to Timeline dispatches exactly once', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await swipeTo(tester, 1);
      expect(repository.timelineCalls, 1);

      await settle(tester, frames: 40);
      expect(repository.timelineCalls, 1);
    });
  });

  group('5. skeleton', () {
    testWidgets('first load shows the Timeline skeleton inside the tab', (
      tester,
    ) async {
      // Never completes, so the panel stays in its first-load state.
      repository.timelineGate = Completer<void>();
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(bloc.state.timelineLoading, isTrue);
      expect(bloc.state.timelineData, isNull);
      expect(find.byType(SkeletonBox), findsWidgets);
      // The prototype lifecycle list must not sit behind the skeleton.
      expect(find.text('Incident lifecycle'), findsNothing);

      // Chrome outside the tab stays put.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('the skeleton leaves after the first load resolves', (
      tester,
    ) async {
      final gate = Completer<void>();
      repository.timelineGate = gate;
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(find.byType(SkeletonBox), findsWidgets);

      gate.complete();
      await settle(tester);

      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('Incident lifecycle'), findsOneWidget);
    });
  });

  group('6. error and retry', () {
    testWidgets('an initial failure shows an inline error with Retry', (
      tester,
    ) async {
      repository.timelineResult = FailureResult(
        const NetworkFailure('Timeline endpoint unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('Timeline endpoint unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Not a full-screen state: the tab chrome survives.
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Retry dispatches Timeline only', (tester) async {
      repository.timelineResult = FailureResult(
        const NetworkFailure('Timeline unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(repository.timelineCalls, 1);
      final generalBefore = repository.detailsCalls;
      final requestsBefore = repository.requestsCalls;

      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(repository.timelineCalls, 2);
      expect(repository.timelineIds.last, kRealIncidentId);
      expect(repository.detailsCalls, generalBefore);
      expect(repository.requestsCalls, requestsBefore);
    });

    testWidgets('a successful retry clears the error', (tester) async {
      repository.timelineResult = FailureResult(
        const NetworkFailure('Timeline unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      repository.timelineResult = Success(kTimelineData());
      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(bloc.state.timelineFailure, isNull);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Incident lifecycle'), findsOneWidget);
    });
  });

  group('7-8. isolation from the other panels', () {
    testWidgets('Timeline loading and failure leave General data intact', (
      tester,
    ) async {
      repository.timelineGate = Completer<void>();
      await pumpScreen(tester);
      await settle(tester);

      final generalBefore = bloc.state.generalData;
      expect(generalBefore, isNotNull);

      await tapTab(tester, 'Timeline');
      await settle(tester);
      expect(bloc.state.timelineLoading, isTrue);
      expect(bloc.state.generalData, generalBefore);
      expect(bloc.state.generalFailure, isNull);

      repository.timelineGate!.complete();
      repository.timelineResult = FailureResult(
        const NetworkFailure('Timeline unavailable'),
      );
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(bloc.state.timelineFailure, isNotNull);
      expect(bloc.state.generalData, generalBefore);
      expect(bloc.state.generalFailure, isNull);

      await tapTab(tester, 'General');
      await settle(tester);
      expect(find.text('General payload that must survive'), findsOneWidget);
    });

    testWidgets(
      'Timeline loading and failure leave Related Requests data intact',
      (tester) async {
        repository.timelineGate = Completer<void>();
        await pumpScreen(tester);
        await settle(tester);

        await tapTab(tester, 'Related Requests');
        await settle(tester);
        final requestsBefore = bloc.state.relatedRequestsData;
        expect(requestsBefore, isNotNull);

        await tapTab(tester, 'Timeline');
        await settle(tester);
        expect(bloc.state.timelineLoading, isTrue);
        expect(bloc.state.relatedRequestsData, requestsBefore);
        expect(bloc.state.relatedRequestsFailure, isNull);

        repository.timelineGate!.complete();
        repository.timelineResult = FailureResult(
          const NetworkFailure('Timeline unavailable'),
        );
        await tapTab(tester, 'Timeline');
        await settle(tester);

        expect(bloc.state.timelineFailure, isNotNull);
        expect(bloc.state.relatedRequestsData, requestsBefore);
        expect(bloc.state.relatedRequestsFailure, isNull);

        await tapTab(tester, 'Related Requests');
        await settle(tester);
        expect(find.text('Request ID: 1'), findsOneWidget);
      },
    );
  });

  group('9-10. real payload rendering and no hardcoded id', () {
    testWidgets('the real payload renders its events', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      // Typed data reached the state through the repository contract.
      expect(bloc.state.timelineData?.events, hasLength(2));
      expect(bloc.state.timelineFailure, isNull);

      // First event: title, user and remarks all come from the payload.
      expect(find.text('Incident Assigned'), findsOneWidget);
      expect(find.text('gsm manager'), findsOneWidget);
      expect(
        find.text(
          'Incident assigned to engineer 1 — status changed to Need Approval',
        ),
        findsOneWidget,
      );

      // Second event.
      await scrollTabDown(tester);
      expect(find.text('Incident Status Changed'), findsOneWidget);
      expect(find.text('engineer 1'), findsOneWidget);
      expect(
        find.text('Status changed from Need Approval to Pending'),
        findsOneWidget,
      );
    });

    testWidgets('every event renders as completed, with the 2 of 2 counter', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('Incident lifecycle'), findsOneWidget);
      // All API events already happened, so all count as completed.
      expect(find.text('2 of 2'), findsOneWidget);

      // One marker per event, all drawn as check icons.
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('events render in the order the API returned them', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      final first = tester.getTopLeft(find.text('Incident Assigned')).dy;
      await scrollTabDown(tester);
      final second = tester.getTopLeft(find.text('Incident Status Changed')).dy;

      // Assign precedes Approve; a sort must not swap them.
      expect(first, lessThan(second));
    });

    testWidgets('oldValue to newValue shows as supplementary text', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('Need Assign \u2192 Need Approval'), findsOneWidget);
    });

    testWidgets('no preview or mapping-pending copy survives', (tester) async {
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      // Sprint 5C placeholder states are gone now that data is real.
      expect(find.textContaining('Preview only'), findsNothing);
      expect(find.textContaining('sample events'), findsNothing);
      expect(find.textContaining('response mapping pending'), findsNothing);
      expect(find.textContaining('data received'), findsNothing);
      expect(find.byIcon(Icons.science_outlined), findsNothing);
    });

    testWidgets('no MockData timeline content leaks into the tab', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);
      await scrollTabDown(tester, dy: -900);

      // Prototype vocabulary from MockData.incidentTimeline.
      for (final mockText in const [
        'تم الإنشاء',
        'تم الإسناد',
        'تم البدء',
        'Field Operations',
      ]) {
        expect(find.text(mockText), findsNothing);
      }
      // 7 prototype events vs the 2 real ones.
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.text('7 of 7'), findsNothing);
    });

    testWidgets('API text is not run through mock localization helpers', (
      tester,
    ) async {
      // `eventType: Assign` would become 'تم الإسناد' under the old helper.
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('Incident Assigned'), findsOneWidget);
      expect(find.text('تم الإسناد'), findsNothing);
      expect(find.text('Assigned'), findsNothing);
    });

    testWidgets('an empty events list shows the localized empty state', (
      tester,
    ) async {
      repository.timelineResult = const Success(kEmptyTimelineData);
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('No timeline events'), findsOneWidget);
      expect(find.byIcon(Icons.timeline_outlined), findsOneWidget);
      // A success, so no error affordance and no retry.
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(bloc.state.timelineFailure, isNull);
    });

    testWidgets('the empty state is localized in Arabic', (tester) async {
      repository.timelineResult = const Success(kEmptyTimelineData);
      await pumpScreen(tester, locale: const Locale('ar'));
      await settle(tester);

      // The tab labels are localized too, so tap the Arabic one.
      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text(
            '\u0627\u0644\u062e\u0637 \u0627\u0644\u0632\u0645\u0646\u064a',
          ),
        ),
      );
      await settle(tester);

      expect(
        repository.timelineCalls,
        1,
        reason: 'the Timeline tab was opened',
      );
      expect(
        find.text(
          '\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u062d\u062f\u0627\u062b \u0641\u064a \u0627\u0644\u062e\u0637 \u0627\u0644\u0632\u0645\u0646\u064a',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a missing events key renders as empty, not a crash', (
      tester,
    ) async {
      // `events` absent leaves the field null.
      repository.timelineResult = const Success(
        IncidentTimelineData(incidentId: 26),
      );
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('No timeline events'), findsOneWidget);
      expect(find.text('0 of 0'), findsOneWidget);
    });

    testWidgets('an event with every optional field null renders dashes', (
      tester,
    ) async {
      repository.timelineResult = const Success(
        IncidentTimelineData(incidentId: 26, events: [kBareTimelineEvent]),
      );
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Incident lifecycle'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      // Title, date and user fall back rather than printing 'null'.
      expect(find.text('-'), findsWidgets);
      expect(find.text('null'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      // No transition line when both values are absent.
      expect(find.textContaining('\u2192'), findsNothing);
    });

    testWidgets('a title falls back through actionType then eventType', (
      tester,
    ) async {
      repository.timelineResult = const Success(
        IncidentTimelineData(
          incidentId: 26,
          events: [
            // No eventTitle: actionType.name wins.
            IncidentTimelineEventDto(actionType: IdNameDto(name: 'Approve')),
            // Neither eventTitle nor actionType: eventType wins.
            IncidentTimelineEventDto(eventType: 'StatusChange'),
            // Nothing at all: a dash.
            IncidentTimelineEventDto(),
          ],
        ),
      );
      await pumpScreen(tester);
      await settle(tester);
      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(find.text('Approve'), findsOneWidget);
      await scrollTabDown(tester);
      expect(find.text('StatusChange'), findsOneWidget);
      await scrollTabDown(tester);
      // Fallback chain exhausted.
      expect(find.text('-'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the incident id always comes from the screen argument', (
      tester,
    ) async {
      // A different real id must reach the API, proving nothing is hardcoded.
      await pumpScreen(tester, incidentId: 4242);
      await settle(tester);

      await tapTab(tester, 'Timeline');
      await settle(tester);

      expect(repository.timelineIds, [4242]);
      expect(repository.timelineIds, isNot(contains(kRealIncidentId)));
    });
  });
}
