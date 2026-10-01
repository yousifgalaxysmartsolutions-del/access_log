import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'support/timeline_fixtures.dart';
import 'package:access_log_plus/widgets/skeleton_shimmer.dart';

/// Records what the General tab forwards and replays canned results.
class _FakeIncidentDetailsRepository implements IncidentDetailsRepository {
  int detailsCalls = 0;
  int timelineCalls = 0;
  int requestsCalls = 0;

  final List<int> detailsIds = [];
  final List<String> detailsNumbers = [];

  Result<IncidentDetailsData> detailsResult = const Success(
    IncidentDetailsData(incidentNo: 'CAP-1'),
  );

  /// Held open while set, so the in-flight loading state can be inspected.
  Completer<void>? gate;

  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    detailsCalls++;
    detailsIds.add(incidentId);
    detailsNumbers.add(incidentNo);
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
    return const Success(IncidentRequestsData(incidentId: 1));
  }
}

/// A distinctive id and number so a test can prove neither is invented.
const int kRealIncidentId = 7391;
const String kRealIncidentNo = 'INC-2026-07391';

CapIncident buildIncident({
  int incidentId = kRealIncidentId,
  String number = kRealIncidentNo,
  CapIncidentStatus status = CapIncidentStatus.pending,
}) => CapIncident(
  incidentId: incidentId,
  number: number,
  type: 'List Type From Screen',
  siteName: 'Site From Screen',
  siteCode: 'SITE-CODE-1',
  region: 'Region From Screen',
  area: 'Area From Screen',
  location: 'Location From Screen',
  title: 'Title From Screen',
  priority: Priority.high,
  dateTime: DateTime(2026, 8, 2, 16, 10),
  status: status,
  currentUser: 'User From Screen',
  // Deliberately different from every API value the test asserts on, so a
  // fallback to `CapIncident` is visible.
  productName: 'Product From Screen',
  nativeMoName: 'NativeMO From Screen',
  notificationType: 'Notification From Screen',
  description: 'Description From Screen',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeIncidentDetailsRepository repository;
  late IncidentDetailsBloc bloc;

  /// Google Maps URLs captured from `url_launcher`.
  late List<Uri> launched;
  TestDefaultBinaryMessengerBinding? messengerBinding;

  setUp(() async {
    await services.reset();
    repository = _FakeIncidentDetailsRepository();

    launched = [];
    messengerBinding = TestDefaultBinaryMessengerBinding.instance;
    messengerBinding!.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add(Uri.parse((call.arguments as Map)['url'] as String));
          return true;
        }
        return true;
      },
    );
  });

  tearDown(() async {
    messengerBinding?.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
    await services.reset();
  });

  Widget testApp(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light(),
    home: home,
  );

  Future<void> pumpScreen(WidgetTester tester, {CapIncident? incident}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The bloc is built here rather than in `setUp` on purpose: `setUp` runs
    // outside the fake-async zone that `testWidgets` installs, so a bloc created
    // there schedules its event-handler continuations as microtasks on the real
    // event loop, which `tester.pump()` can never flush. Inside the test body
    // those microtasks belong to the fake-async zone and resolve normally.
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
  /// `pumpAndSettle` cannot be used while the shimmer placeholder is on screen
  /// because its controller repeats forever; a bounded sequence of pumps lets
  /// the bloc's async work and the tab animations finish without waiting for
  /// quiescence.
  Future<void> settle(
    WidgetTester tester, {
    int frames = 20,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  }

  /// The Directions button, found through the site name it renders.
  ///
  /// Its `Semantics` label merges with that name, so a label finder cannot match
  /// it exactly; the button is the only `InkWell` that wraps the name.
  Finder directionsButton() => find.ancestor(
    of: find.text('North Tower'),
    matching: find.byType(InkWell),
  );

  /// Scrolls the General tab down so cards below the fold are built.
  Future<void> scrollGeneralDown(
    WidgetTester tester, {
    double dy = -400,
  }) async {
    await tester.drag(find.byType(ListView).first, Offset(0, dy));
    await settle(tester, frames: 6);
  }

  group('1-2. initial load', () {
    testWidgets('opening the screen triggers exactly one General load', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      expect(repository.detailsCalls, 1);
      expect(repository.detailsIds, [kRealIncidentId]);
      expect(repository.detailsNumbers, [kRealIncidentNo]);
    });

    testWidgets('opening the screen loads General only', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      // The other two panels load when their tab is selected, not on open.
      expect(repository.timelineCalls, 0);
      expect(repository.requestsCalls, 0);
    });

    testWidgets('the skeleton shows on the first load, inside the tab only', (
      tester,
    ) async {
      // Never completes, so the tab stays in its first-load state.
      repository.gate = Completer<void>();
      await pumpScreen(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(bloc.state.generalLoading, isTrue);
      expect(bloc.state.generalData, isNull);

      // The surrounding screen stays usable.
      expect(find.text('Incident Details'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Related Requests'), findsOneWidget);
    });
  });

  group('4-5. success mapping', () {
    setUp(() {
      repository.detailsResult = const Success(
        IncidentDetailsData(
          id: kRealIncidentId,
          incidentNo: kRealIncidentNo,
          title: 'Fiber cut on feeder A',
          description: 'Primary fiber path is down.',
          productName: 'Mobile Network',
          nativeMoName: 'MO-4471',
          createdDate: '2026-08-02T16:10:00',
          notificationType: IdNameDto(name: 'Operational Alarm'),
          status: IdNameDto(name: 'In Process'),
          priority: IdNameDto(name: 'High'),
          incidentType: IdNameDto(name: 'Transmission'),
          assignedEngineer: IdNameDto(name: 'Sara Samir'),
          location: IncidentLocationDto(
            id: 'LOC-77',
            name: 'North Tower',
            region: IdNameDto(name: 'Cairo'),
            area: IdNameDto(name: 'Maadi'),
            latitude: 24.5,
            longitude: 55.7,
          ),
        ),
      );
    });

    testWidgets('renders the real API values', (tester) async {
      await pumpScreen(tester);
      await settle(tester);

      // Once in the CapIncident header, once in the General tab from the API.
      expect(find.text(kRealIncidentNo), findsNWidgets(2));
      expect(find.text('Transmission'), findsOneWidget);
      expect(find.text('Fiber cut on feeder A'), findsOneWidget);
      expect(find.text('In Process'), findsOneWidget);
      expect(find.text('Sara Samir'), findsOneWidget);

      // The remaining cards are below the fold on a phone-sized viewport.
      await scrollGeneralDown(tester);
      await scrollGeneralDown(tester);
      // Site Name row and the Directions button both carry the API name.
      expect(find.text('North Tower'), findsNWidgets(2));
      expect(find.text('LOC-77'), findsOneWidget);
      expect(find.text('Cairo'), findsOneWidget);
      expect(find.text('Maadi'), findsOneWidget);
      expect(find.text('Operational Alarm'), findsOneWidget);
      expect(find.text('Mobile Network'), findsOneWidget);
      expect(find.text('MO-4471'), findsOneWidget);
      expect(find.text('Primary fiber path is down.'), findsOneWidget);
    });

    testWidgets('does not fall back to CapIncident or mock content', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      // Values that only exist on the screen's `CapIncident`.
      expect(find.text('Product From Screen'), findsNothing);
      expect(find.text('NativeMO From Screen'), findsNothing);
      expect(find.text('Notification From Screen'), findsNothing);
      expect(find.text('Description From Screen'), findsNothing);
      expect(find.text('Site From Screen'), findsNothing);
    });

    testWidgets('formats the API created date', (tester) async {
      await pumpScreen(tester);
      await settle(tester);
      await scrollGeneralDown(tester);
      await scrollGeneralDown(tester);

      expect(find.textContaining('02/08/2026'), findsOneWidget);
      expect(find.textContaining('Aug 2026 •'), findsNothing);
    });

    testWidgets('null fields render as a dash and never as "null"', (
      tester,
    ) async {
      repository.detailsResult = const Success(IncidentDetailsData(id: 1));
      await pumpScreen(tester);
      await settle(tester);

      expect(find.text('-'), findsWidgets);
      expect(find.textContaining('null', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null location renders gracefully', (tester) async {
      repository.detailsResult = const Success(
        IncidentDetailsData(id: 1, title: 'No location'),
      );
      await pumpScreen(tester);
      await settle(tester);

      expect(find.text('No location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('6. error and retry', () {
    testWidgets('a failure with no data shows an inline General error', (
      tester,
    ) async {
      repository.detailsResult = const FailureResult(
        ServerFailure('Service unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);

      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
      // Still inside the tab: chrome and actions remain.
      expect(find.text('Incident Details'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('Retry dispatches General only', (tester) async {
      repository.detailsResult = const FailureResult(
        ServerFailure('Service unavailable'),
      );
      await pumpScreen(tester);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      await tester.tap(find.text('Retry'));
      await settle(tester);

      expect(repository.detailsCalls, 2);
      expect(repository.detailsIds, [kRealIncidentId, kRealIncidentId]);
      expect(repository.timelineCalls, 0);
      expect(repository.requestsCalls, 0);
    });

    testWidgets('a failure after data keeps the last successful payload', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(find.text('CAP-1'), findsOneWidget);

      repository.detailsResult = const FailureResult(
        NetworkFailure('Network unavailable'),
      );
      await tester.tap(find.text('General'));
      await settle(tester);

      expect(find.text('CAP-1'), findsOneWidget);
      expect(find.text('Network unavailable'), findsOneWidget);
      // The retained payload is still rendered, not swapped for a full-page error.
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('7. refresh keeps data', () {
    testWidgets('refreshing keeps content and skips the full skeleton', (
      tester,
    ) async {
      repository.detailsResult = const Success(
        IncidentDetailsData(id: kRealIncidentId, incidentNo: 'CAP-STABLE'),
      );
      await pumpScreen(tester);
      await settle(tester);
      expect(find.text('CAP-STABLE'), findsOneWidget);

      final gate = Completer<void>();
      repository.gate = gate;
      await tester.tap(find.text('General'));
      await tester.pump();
      await tester.pump();

      expect(bloc.state.generalLoading, isTrue);
      expect(find.text('CAP-STABLE'), findsOneWidget);
      expect(find.text('Refreshing…'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);

      gate.complete();
      await settle(tester);
      expect(find.text('CAP-STABLE'), findsOneWidget);
      expect(find.text('Refreshing…'), findsNothing);
    });
  });

  group('8-10. deliberate re-selection', () {
    testWidgets('leaving General and coming back loads it again', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      await tester.tap(find.text('Timeline'));
      await settle(tester);
      expect(
        repository.detailsCalls,
        1,
        reason: 'Timeline must not load General',
      );

      await tester.tap(find.text('General'));
      await settle(tester);
      expect(repository.detailsCalls, 2);
    });

    testWidgets('re-tapping the selected General tab loads it exactly once', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      await tester.tap(find.text('General'));
      await settle(tester);
      expect(repository.detailsCalls, 2);

      await tester.tap(find.text('General'));
      await settle(tester);
      expect(repository.detailsCalls, 3);
    });

    testWidgets('swiping away and back loads General exactly once', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      // Swipe to the next tab and back.
      await tester.fling(find.byType(TabBarView), const Offset(-350, 0), 900);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      await tester.fling(find.byType(TabBarView), const Offset(350, 0), 900);
      await settle(tester);
      expect(repository.detailsCalls, 2);
    });

    testWidgets('a tab change dispatches Timeline but never twice', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);

      await tester.tap(find.text('Timeline'));
      await settle(tester);
      await tester.tap(find.text('Related Requests'));
      await settle(tester);
      // The scrollable TabBar has moved General off screen to the left.
      await tester.ensureVisible(find.text('General'));
      await settle(tester, frames: 6);
      await tester.tap(find.text('General'));
      await settle(tester);

      expect(repository.detailsCalls, 2);
      // Sprints 5B and 5C wire the other two panels, so visiting each now
      // issues one request. Neither may trigger an extra General request.
      expect(repository.timelineCalls, 1);
      expect(repository.requestsCalls, 1);
    });
  });

  group('11. directions', () {
    testWidgets('uses the API coordinates, not MockData.towerSites', (
      tester,
    ) async {
      repository.detailsResult = const Success(
        IncidentDetailsData(
          id: kRealIncidentId,
          location: IncidentLocationDto(
            id: 'LOC-77',
            name: 'North Tower',
            latitude: 24.5,
            longitude: 55.7,
          ),
        ),
      );
      await pumpScreen(tester);
      await settle(tester);
      await scrollGeneralDown(tester);

      await tester.tap(directionsButton());
      await settle(tester);

      expect(launched, hasLength(1));
      final url = launched.single.toString();
      expect(url, contains('/maps/dir/'));
      // `Uri.https` percent-encodes the comma in the destination pair.
      expect(url, contains('destination=24.5%2C55.7'));
      // The prototype site code is what the old MockData lookup matched on.
      expect(url, isNot(contains('SITE-CODE-1')));
    });

    testWidgets('missing coordinates show the localized message', (
      tester,
    ) async {
      repository.detailsResult = const Success(
        IncidentDetailsData(
          id: kRealIncidentId,
          location: IncidentLocationDto(id: 'LOC-77', name: 'North Tower'),
        ),
      );
      await pumpScreen(tester);
      await settle(tester);
      await scrollGeneralDown(tester);

      await tester.tap(directionsButton());
      await settle(tester);

      expect(launched, isEmpty);
      expect(find.text('Tower coordinates are not available.'), findsOneWidget);
    });
  });

  group('bloc lifetime', () {
    testWidgets('the screen resolves one bloc and closes it on dispose', (
      tester,
    ) async {
      await pumpScreen(tester);
      await settle(tester);
      expect(repository.detailsCalls, 1);

      // Re-selecting does not create a second bloc, so the counter keeps
      // climbing on the same repository instance.
      await tester.tap(find.text('General'));
      await settle(tester);
      expect(repository.detailsCalls, 2);

      await tester.pumpWidget(testApp(const SizedBox()));
      await settle(tester);
      expect(bloc.isClosed, isTrue);
    });
  });
}
