import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_details_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_timeline_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_details_bloc.dart';

import 'support/timeline_fixtures.dart';

/// Records what each panel forwards and replays a canned [Result].
///
/// [gate] lets a test hold a request open so the in-flight loading state can be
/// observed, which is where the "refresh keeps data" and "retry clears error"
/// behaviour is visible.
class _FakeIncidentDetailsRepository implements IncidentDetailsRepository {
  int detailsCalls = 0;
  int timelineCalls = 0;
  int requestsCalls = 0;

  final List<int> detailsIds = [];
  final List<String> detailsNumbers = [];
  final List<int> timelineIds = [];
  final List<int> requestsIds = [];

  Result<IncidentDetailsData> detailsResult = const Success(
    IncidentDetailsData(id: 26, title: 'Test Incident - D10739'),
  );

  /// Needs Verification: still untyped, so the tests only assert the value is
  /// forwarded untouched rather than inspecting Timeline fields.
  Result<IncidentTimelineData> timelineResult = const Success(
    kEmptyTimelineData,
  );

  Result<IncidentRequestsData> requestsResult = const Success(
    IncidentRequestsData(incidentId: 1, incidentNo: 'INC-0001'),
  );

  Completer<void>? gate;

  /// When true, every call parks on its own completer so a test can finish
  /// overlapping calls in any order.
  bool parkCalls = false;
  final List<Completer<void>> parked = [];

  /// Optional per-call results, so two overlapping calls can return different
  /// payloads. Falls back to [detailsResult] when unset.
  List<Result<IncidentDetailsData>>? detailsScript;
  List<Result<IncidentRequestsData>>? requestsScript;
  List<Result<IncidentTimelineData>>? timelineResults;

  Future<void> _wait() async {
    if (parkCalls) {
      final completer = Completer<void>();
      parked.add(completer);
      await completer.future;
      return;
    }
    final current = gate;
    if (current != null) await current.future;
  }

  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    detailsCalls++;
    // Captured before awaiting: reading it afterwards would let a late call
    // pick up a newer call's scripted result.
    final call = detailsCalls;
    detailsIds.add(incidentId);
    detailsNumbers.add(incidentNo);
    await _wait();
    return detailsScript?[call - 1] ?? detailsResult;
  }

  @override
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  }) async {
    timelineCalls++;
    final call = timelineCalls;
    timelineIds.add(incidentId);
    await _wait();
    return timelineResults?[call - 1] ?? timelineResult;
  }

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    requestsCalls++;
    final call = requestsCalls;
    requestsIds.add(incidentId);
    await _wait();
    return requestsScript?[call - 1] ?? requestsResult;
  }
}

void main() {
  late _FakeIncidentDetailsRepository repository;
  late IncidentDetailsBloc bloc;

  setUp(() {
    repository = _FakeIncidentDetailsRepository();
    bloc = IncidentDetailsBloc(
      getIncidentDetails: GetIncidentDetailsUseCase(repository),
      getIncidentTimeline: GetIncidentTimelineUseCase(repository),
      getIncidentRequests: GetIncidentRequestsUseCase(repository),
    );
  });

  tearDown(() => bloc.close());

  const general = LoadIncidentGeneral(incidentId: 26, incidentNo: '');
  const timeline = LoadIncidentTimeline(incidentId: 26);
  const related = LoadIncidentRelatedRequests(incidentId: 1);

  const incident = IncidentDetailsData(id: 26);
  final requestsWithTwo = IncidentRequestsData(
    incidentId: 1,
    incidentNo: 'INC-0001',
    items: const [
      IncidentRequestItemDto(
        id: 1,
        requestStatus: IdNameDto(id: 2, name: 'Approved'),
      ),
      IncidentRequestItemDto(
        id: 2,
        requestStatus: IdNameDto(id: 3, name: 'Rejected'),
      ),
    ],
  );

  test('1. initial state has nothing loading and no data or errors', () {
    final state = bloc.state;

    expect(state.generalLoading, isFalse);
    expect(state.generalData, isNull);
    expect(state.generalFailure, isNull);
    expect(state.timelineLoading, isFalse);
    expect(state.timelineData, isNull);
    expect(state.timelineFailure, isNull);
    expect(state.relatedRequestsLoading, isFalse);
    expect(state.relatedRequestsData, isNull);
    expect(state.relatedRequestsFailure, isNull);
    expect(state.hasContent, isFalse);
  });

  test('1b. nothing is loaded before an event arrives', () async {
    await Future<void>.delayed(Duration.zero);

    expect(repository.detailsCalls, 0);
    expect(repository.timelineCalls, 0);
    expect(repository.requestsCalls, 0);
  });

  group('2. general success', () {
    test('emits loading, then the incident', () async {
      bloc.add(general);
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<IncidentDetailsState>((s) => s.generalLoading),
          predicate<IncidentDetailsState>(
            (s) =>
                !s.generalLoading &&
                s.generalData?.id == 26 &&
                s.generalFailure == null,
          ),
        ]),
      );

      expect(repository.detailsIds, [26]);
      expect(repository.detailsNumbers, ['']);
    });
  });

  group('3. general failure', () {
    test('emits loading, then the failure', () async {
      repository.detailsResult = const FailureResult(
        UnauthorizedFailure('Sign in again'),
      );

      bloc.add(general);
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<IncidentDetailsState>((s) => s.generalLoading),
          predicate<IncidentDetailsState>(
            (s) => !s.generalLoading && s.generalFailure != null,
          ),
        ]),
      );

      expect(bloc.state.generalFailure, isA<UnauthorizedFailure>());
      expect(bloc.state.generalData, isNull);
    });
  });

  group('4. timeline success', () {
    test('changes only the timeline fields', () async {
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);

      final payload = kTimelineData();
      repository.timelineResult = Success(payload);

      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      // The typed payload arrives intact, events included.
      expect(bloc.state.timelineData, same(payload));
      expect(bloc.state.timelineData?.events, hasLength(2));
      expect(
        bloc.state.timelineData?.events?.first.eventTitle,
        'Incident Assigned',
      );
      expect(
        bloc.state.timelineData?.events?.first.performedBy?.name,
        'gsm manager',
      );
      expect(bloc.state.timelineFailure, isNull);
      expect(repository.timelineIds, [26]);

      // The general panel is exactly as it was.
      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.generalFailure, isNull);
      expect(bloc.state.generalLoading, isFalse);
    });

    test('does not touch related requests', () async {
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      expect(bloc.state.relatedRequestsData?.incidentNo, 'INC-0001');
      expect(bloc.state.relatedRequestsFailure, isNull);
      expect(bloc.state.generalData, isNull);
    });
  });

  group('5. related requests success', () {
    test('emits loading, then two items', () async {
      repository.requestsResult = Success(requestsWithTwo);

      bloc.add(related);
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<IncidentDetailsState>((s) => s.relatedRequestsLoading),
          predicate<IncidentDetailsState>(
            (s) =>
                !s.relatedRequestsLoading &&
                s.relatedRequestsData?.items?.length == 2 &&
                s.relatedRequestsFailure == null,
          ),
        ]),
      );

      expect(repository.requestsIds, [1]);
      expect(
        bloc.state.relatedRequestsData?.items?.first.requestStatus?.name,
        'Approved',
      );
      expect(
        bloc.state.relatedRequestsData?.items?.last.requestStatus?.name,
        'Rejected',
      );
    });
  });

  group('6. empty related requests is a success', () {
    test('items: [] produces data and no failure', () async {
      repository.requestsResult = const Success(
        IncidentRequestsData(incidentId: 1, incidentNo: 'INC-0001', items: []),
      );

      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      expect(bloc.state.relatedRequestsData, isNotNull);
      expect(bloc.state.relatedRequestsData?.items, isEmpty);
      expect(bloc.state.relatedRequestsFailure, isNull);
    });
  });

  group('7. independent state preservation', () {
    test('all three panels coexist once loaded', () async {
      final payload = kTimelineData();
      repository.timelineResult = Success(payload);
      repository.requestsResult = Success(requestsWithTwo);

      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      final state = bloc.state;
      expect(state.generalData?.id, 26);
      expect(state.timelineData, payload);
      expect(state.relatedRequestsData?.items?.length, 2);
      expect(state.generalFailure, isNull);
      expect(state.timelineFailure, isNull);
      expect(state.relatedRequestsFailure, isNull);
      expect(state.hasContent, isTrue);
    });

    test('general survives while timeline is still loading', () async {
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);

      // Hold only the timeline request open.
      repository.gate = Completer<void>();
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => s.timelineLoading);

      expect(bloc.state.timelineLoading, isTrue);
      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.generalFailure, isNull);

      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      expect(bloc.state.generalData?.id, 26);
    });
  });

  group('8. refresh keeps existing data', () {
    test('general keeps its incident while the second call runs', () async {
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      expect(bloc.state.generalData?.id, 26);

      repository.gate = Completer<void>();
      bloc.add(general);
      await bloc.stream.firstWhere((s) => s.generalLoading);

      expect(bloc.state.generalLoading, isTrue);
      expect(bloc.state.generalData?.id, 26, reason: 'data wiped on refresh');
      expect(bloc.state.generalFailure, isNull);

      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      expect(bloc.state.generalData?.id, 26);
    });

    test('related requests keep their items while refreshing', () async {
      repository.requestsResult = Success(
        IncidentRequestsData(
          incidentId: 1,
          incidentNo: 'INC-0001',
          items: const [IncidentRequestItemDto(id: 1)],
        ),
      );
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      repository.gate = Completer<void>();
      bloc.add(related);
      await bloc.stream.firstWhere((s) => s.relatedRequestsLoading);

      expect(bloc.state.relatedRequestsData?.items?.length, 1);

      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);
      expect(bloc.state.relatedRequestsData?.items?.length, 1);
    });

    test('timeline keeps its payload while refreshing', () async {
      final payload = kTimelineData();
      repository.timelineResult = Success(payload);

      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      repository.gate = Completer<void>();
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => s.timelineLoading);

      expect(bloc.state.timelineData, payload);

      repository.gate!.complete();
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      expect(bloc.state.timelineData, payload);
    });
  });

  group('9. retry clears the previous error', () {
    test(
      'the error is cleared during loading, then replaced by data',
      () async {
        repository.detailsResult = const FailureResult(
          ServerFailure('Service unavailable'),
        );
        bloc.add(general);
        await bloc.stream.firstWhere((s) => !s.generalLoading);
        expect(bloc.state.generalFailure, isNotNull);

        repository.gate = Completer<void>();
        repository.detailsResult = const Success(incident);

        bloc.add(general);
        await bloc.stream.firstWhere((s) => s.generalLoading);

        // A stale error must not survive into the retry.
        expect(bloc.state.generalFailure, isNull);
        expect(bloc.state.generalLoading, isTrue);

        repository.gate!.complete();
        await bloc.stream.firstWhere((s) => !s.generalLoading);

        expect(bloc.state.generalData, isNotNull);
        expect(bloc.state.generalFailure, isNull);
      },
    );

    test('a failure after a success keeps the last known incident', () async {
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);

      repository.detailsResult = const FailureResult(
        TimeoutFailure('Request timed out'),
      );
      bloc.add(general);
      await bloc.stream.firstWhere(
        (s) => !s.generalLoading && s.generalFailure != null,
      );

      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.generalFailure, isA<TimeoutFailure>());
    });

    test('a related requests retry clears its error too', () async {
      repository.requestsResult = const FailureResult(
        NetworkFailure('Network unavailable'),
      );
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);
      expect(bloc.state.relatedRequestsFailure, isNotNull);

      repository.requestsResult = const Success(
        IncidentRequestsData(incidentId: 1, incidentNo: 'INC-0001'),
      );
      bloc.add(related);
      await bloc.stream.firstWhere((s) => s.relatedRequestsLoading);

      expect(bloc.state.relatedRequestsFailure, isNull);

      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);
      expect(bloc.state.relatedRequestsFailure, isNull);
      expect(bloc.state.relatedRequestsData?.incidentNo, 'INC-0001');
    });
  });

  group('10. repeated events execute repeatedly', () {
    test(
      'general is fetched again with no already-loaded short-circuit',
      () async {
        bloc.add(general);
        await bloc.stream.firstWhere((s) => !s.generalLoading);
        bloc.add(general);
        await bloc.stream.firstWhere((s) => !s.generalLoading);

        expect(repository.detailsCalls, 2);
        expect(repository.detailsIds, [26, 26]);
      },
    );

    test('related requests is fetched again', () async {
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      expect(repository.requestsCalls, 2);
    });

    test('timeline is fetched again', () async {
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      expect(repository.timelineCalls, 2);
    });
  });

  group('12. out-of-order responses per tab', () {
    /// Waits until [count] calls have parked, so the test controls completion
    /// order.
    Future<void> untilParked(int count) async {
      while (repository.parked.length < count) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    /// Drains the event queue so a stale handler, if it were going to emit,
    /// would already have done so. Counting turns is deterministic where a
    /// fixed sleep is not.
    Future<void> flush() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a stale General response cannot overwrite a newer one', () async {
      final seen = <IncidentDetailsState>[];
      final sub = bloc.stream.listen(seen.add);
      addTearDown(sub.cancel);

      repository.parkCalls = true;
      repository.detailsScript = const [
        Success(IncidentDetailsData(id: 1, title: 'stale A')),
        Success(IncidentDetailsData(id: 26, title: 'fresh B')),
      ];

      // Call A starts.
      bloc.add(general);
      await untilParked(1);

      // Call B starts before A has returned.
      bloc.add(general);
      await untilParked(2);
      expect(repository.detailsCalls, 2, reason: 'the second load never ran');

      // B resolves first.
      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      expect(bloc.state.generalData?.title, 'fresh B');
      final emissionsBeforeStale = seen.length;

      // A resolves afterwards and must be ignored.
      repository.parked[0].complete();
      await flush();

      expect(bloc.state.generalData?.id, 26);
      expect(
        bloc.state.generalData?.title,
        'fresh B',
        reason: 'stale response overwrote the newer one',
      );
      expect(bloc.state.generalFailure, isNull);
      expect(
        seen.length,
        emissionsBeforeStale,
        reason: 'the superseded request emitted a state',
      );
    });

    test(
      'a stale Related Requests response cannot overwrite a newer one',
      () async {
        repository.parkCalls = true;
        repository.requestsScript = const [
          Success(IncidentRequestsData(incidentId: 1, incidentNo: 'STALE')),
          Success(IncidentRequestsData(incidentId: 1, incidentNo: 'FRESH')),
        ];

        bloc.add(related);
        await untilParked(1);
        bloc.add(related);
        await untilParked(2);

        repository.parked[1].complete();
        await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);
        expect(bloc.state.relatedRequestsData?.incidentNo, 'FRESH');

        repository.parked[0].complete();
        await flush();

        expect(bloc.state.relatedRequestsData?.incidentNo, 'FRESH');
        expect(bloc.state.relatedRequestsFailure, isNull);
      },
    );

    test('a stale Timeline response cannot overwrite a newer one', () async {
      repository.parkCalls = true;
      repository.timelineResults = [
        Success(IncidentTimelineData(incidentNo: 'stale A')),
        Success(IncidentTimelineData(incidentNo: 'fresh B')),
      ];

      bloc.add(timeline);
      await untilParked(1);
      bloc.add(timeline);
      await untilParked(2);

      expect(repository.timelineCalls, 2);
      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      expect(bloc.state.timelineData?.incidentNo, 'fresh B');

      repository.parked[0].complete();
      await flush();

      // The late stale response must not overwrite the newer one.
      expect(bloc.state.timelineData?.incidentNo, 'fresh B');
    });

    test('a stale failure cannot clobber a newer General success', () async {
      repository.parkCalls = true;
      repository.detailsScript = const [
        FailureResult(ServerFailure('stale failure')),
        Success(IncidentDetailsData(id: 26, title: 'fresh B')),
      ];

      bloc.add(general);
      await untilParked(1);
      bloc.add(general);
      await untilParked(2);

      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      expect(bloc.state.generalFailure, isNull);

      repository.parked[0].complete();
      await flush();

      expect(bloc.state.generalData?.id, 26);
      expect(
        bloc.state.generalFailure,
        isNull,
        reason: 'stale failure surfaced after a newer success',
      );
    });

    test('a stale success cannot clobber a newer failure', () async {
      repository.parkCalls = true;
      repository.detailsScript = const [
        Success(IncidentDetailsData(id: 1, title: 'stale A')),
        FailureResult(ServerFailure('fresh failure')),
      ];

      bloc.add(general);
      await untilParked(1);
      bloc.add(general);
      await untilParked(2);

      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      expect(bloc.state.generalFailure, isA<ServerFailure>());

      repository.parked[0].complete();
      await flush();

      expect(bloc.state.generalFailure, isA<ServerFailure>());
      expect(bloc.state.generalData, isNull);
    });

    test('a superseded General load leaves other tabs untouched', () async {
      repository.requestsResult = Success(requestsWithTwo);
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      repository.parkCalls = true;
      repository.detailsScript = const [
        Success(IncidentDetailsData(id: 1, title: 'stale A')),
        Success(IncidentDetailsData(id: 26, title: 'fresh B')),
      ];

      bloc.add(general);
      await untilParked(1);
      bloc.add(general);
      await untilParked(2);

      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.generalLoading);
      repository.parked[0].complete();
      await flush();

      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.relatedRequestsData?.items?.length, 2);
      expect(bloc.state.relatedRequestsFailure, isNull);
      expect(bloc.state.generalLoading, isFalse);
    });

    test('panels are not serialised behind one queue', () async {
      repository.parkCalls = true;

      // All three in flight at once.
      bloc.add(general);
      await untilParked(1);
      bloc.add(timeline);
      await untilParked(2);
      bloc.add(related);
      await untilParked(3);

      expect(repository.detailsCalls, 1);
      expect(repository.timelineCalls, 1);
      expect(repository.requestsCalls, 1);
      expect(bloc.state.generalLoading, isTrue);
      expect(bloc.state.timelineLoading, isTrue);
      expect(bloc.state.relatedRequestsLoading, isTrue);

      // Timeline settles while the other two are still parked, proving there is
      // no global queue and no cross-panel cancellation.
      repository.parked[1].complete();
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      expect(bloc.state.timelineFailure, isNull);
      expect(bloc.state.generalLoading, isTrue);
      expect(bloc.state.relatedRequestsLoading, isTrue);

      repository.parked[0].complete();
      repository.parked[2].complete();
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.relatedRequestsData?.incidentNo, 'INC-0001');
      expect(bloc.state.generalLoading, isFalse);
    });
  });

  group('11. failure isolation', () {
    test('a timeline failure leaves general untouched', () async {
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);

      repository.timelineResult = const FailureResult(
        NetworkFailure('Network unavailable'),
      );
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);

      expect(bloc.state.timelineFailure, isA<NetworkFailure>());
      expect(bloc.state.generalData?.id, 26);
      expect(bloc.state.generalFailure, isNull);
      expect(bloc.state.generalLoading, isFalse);
    });

    test(
      'a related requests failure leaves general and timeline untouched',
      () async {
        final payload = kTimelineData();
        repository.timelineResult = Success(payload);
        bloc.add(general);
        await bloc.stream.firstWhere((s) => !s.generalLoading);
        bloc.add(timeline);
        await bloc.stream.firstWhere((s) => !s.timelineLoading);

        repository.requestsResult = const FailureResult(
          ServerFailure('Service unavailable'),
        );
        bloc.add(related);
        await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

        expect(bloc.state.relatedRequestsFailure, isA<ServerFailure>());
        expect(bloc.state.generalData?.id, 26);
        expect(bloc.state.timelineData, payload);
        expect(bloc.state.timelineFailure, isNull);
      },
    );

    test('a general failure does not clear other panels', () async {
      final payload = kTimelineData();
      repository.timelineResult = Success(payload);
      bloc.add(timeline);
      await bloc.stream.firstWhere((s) => !s.timelineLoading);
      bloc.add(related);
      await bloc.stream.firstWhere((s) => !s.relatedRequestsLoading);

      repository.detailsResult = const FailureResult(
        UnauthorizedFailure('Sign in again'),
      );
      bloc.add(general);
      await bloc.stream.firstWhere((s) => !s.generalLoading);

      expect(bloc.state.generalFailure, isA<UnauthorizedFailure>());
      expect(bloc.state.timelineData, payload);
      expect(bloc.state.relatedRequestsData?.incidentNo, 'INC-0001');
    });
  });
}
