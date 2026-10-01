import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_details_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_timeline_use_case.dart';

import 'support/timeline_fixtures.dart';

/// Records what each use case forwards and replays a canned [Result].
///
/// Use cases must only delegate, so this fake never inspects payloads; the
/// repository's own behaviour is covered by the repository tests.
class _FakeIncidentDetailsRepository implements IncidentDetailsRepository {
  int detailsCalls = 0;
  int timelineCalls = 0;
  int requestsCalls = 0;

  int? lastDetailsId;
  String? lastDetailsNo;
  int? lastTimelineId;
  int? lastRequestsId;

  Result<IncidentDetailsData> detailsResult = const FailureResult(
    UnauthorizedFailure('no session'),
  );
  Result<IncidentTimelineData> timelineResult = const Success(
    kEmptyTimelineData,
  );
  Result<IncidentRequestsData> requestsResult = const FailureResult(
    UnauthorizedFailure('no session'),
  );

  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    detailsCalls++;
    lastDetailsId = incidentId;
    lastDetailsNo = incidentNo;
    return detailsResult;
  }

  @override
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  }) async {
    timelineCalls++;
    lastTimelineId = incidentId;
    return timelineResult;
  }

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    requestsCalls++;
    lastRequestsId = incidentId;
    return requestsResult;
  }
}

const _details = IncidentDetailsData(id: 26, title: 'Test Incident - D10739');
const _requests = IncidentRequestsData(incidentId: 1, incidentNo: 'INC-0001');

void main() {
  late _FakeIncidentDetailsRepository repository;

  setUp(() => repository = _FakeIncidentDetailsRepository());

  group('GetIncidentDetailsUseCase', () {
    test('forwards incidentId and incidentNo exactly', () async {
      await GetIncidentDetailsUseCase(repository)(
        incidentId: 26,
        incidentNo: '',
      );

      expect(repository.detailsCalls, 1);
      expect(repository.lastDetailsId, 26);
      expect(repository.lastDetailsNo, '');
    });

    test(
      'accepts an empty incidentNo, which the General API supports',
      () async {
        // Must not be rejected locally: CAP takes "IncidentNo": "".
        await GetIncidentDetailsUseCase(repository)(
          incidentId: 26,
          incidentNo: '',
        );

        expect(repository.lastDetailsNo, '');
      },
    );

    test('forwards a supplied incidentNo untouched', () async {
      await GetIncidentDetailsUseCase(repository)(
        incidentId: 26,
        incidentNo: 'INC-SEED-D10739-04',
      );

      expect(repository.lastDetailsNo, 'INC-SEED-D10739-04');
    });

    test('returns the repository success unchanged', () async {
      repository.detailsResult = const Success(_details);

      final result = await GetIncidentDetailsUseCase(repository)(
        incidentId: 26,
        incidentNo: '',
      );

      expect(result, isA<Success<IncidentDetailsData>>());
      expect((result as Success).data, same(_details));
    });
  });

  group('GetIncidentTimelineUseCase', () {
    test('calls the repository once with incidentId', () async {
      await GetIncidentTimelineUseCase(repository)(incidentId: 26);

      expect(repository.timelineCalls, 1);
      expect(repository.lastTimelineId, 26);
    });

    test('forwards the typed success unchanged', () async {
      final data = kTimelineData();
      repository.timelineResult = Success(data);

      final result = await GetIncidentTimelineUseCase(repository)(
        incidentId: 26,
      );

      expect(result, isA<Success<IncidentTimelineData>>());
      // Same instance, not a copy: the use case adds no mapping of its own.
      expect((result as Success).data, same(data));
      expect(
        (result as Success).data.events,
        hasLength(2),
        reason: 'the typed payload reaches the use case intact',
      );
    });

    test('forwards a failure unchanged', () async {
      repository.timelineResult = const FailureResult(
        ServerFailure('timeline unavailable'),
      );

      final result = await GetIncidentTimelineUseCase(repository)(
        incidentId: 26,
      );

      expect(result, isA<FailureResult<IncidentTimelineData>>());
    });

    test('forwards an empty timeline as success, not failure', () async {
      repository.timelineResult = const Success(kEmptyTimelineData);

      final result = await GetIncidentTimelineUseCase(repository)(
        incidentId: 26,
      );

      expect(result, isA<Success<IncidentTimelineData>>());
      expect((result as Success).data.events, isEmpty);
    });
  });

  group('GetIncidentRequestsUseCase', () {
    test('calls the repository once with incidentId', () async {
      await GetIncidentRequestsUseCase(repository)(incidentId: 1);

      expect(repository.requestsCalls, 1);
      expect(repository.lastRequestsId, 1);
    });

    test('returns the repository success unchanged', () async {
      repository.requestsResult = const Success(_requests);

      final result = await GetIncidentRequestsUseCase(repository)(
        incidentId: 1,
      );

      expect(result, isA<Success<IncidentRequestsData>>());
      expect((result as Success).data, same(_requests));
    });
  });

  group('D. failure forwarding', () {
    test('a details FailureResult is passed through, not swallowed', () async {
      const failure = UnauthorizedFailure('Sign in again');
      repository.detailsResult = const FailureResult(failure);

      final result = await GetIncidentDetailsUseCase(repository)(
        incidentId: 26,
        incidentNo: '',
      );

      expect(result, isA<FailureResult<IncidentDetailsData>>());
      expect((result as FailureResult).failure, same(failure));
    });

    test('a requests FailureResult keeps its type and message', () async {
      const failure = ServiceFailure('cap_result_0', 'Failed');
      repository.requestsResult = const FailureResult(failure);

      final result = await GetIncidentRequestsUseCase(repository)(
        incidentId: 1,
      );

      final failureResult = result as FailureResult<IncidentRequestsData>;
      expect(failureResult.failure, isA<ServiceFailure>());
      expect(failureResult.failure.message, 'Failed');
    });

    test('a timeline FailureResult is not converted into a success', () async {
      repository.timelineResult = const FailureResult(
        ServiceFailure('cap_result_0', 'Failed'),
      );

      final result = await GetIncidentTimelineUseCase(repository)(
        incidentId: 26,
      );

      expect(result, isA<FailureResult<Object?>>());
    });
  });
}
