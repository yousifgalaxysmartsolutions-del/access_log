import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_lookup_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_list_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/approve_request_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/reject_request_use_case.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart'
    show IdNameDto;
import 'package:access_log_plus/features/requests/presentation/bloc/request_list_bloc.dart';

class _Repository implements RequestRepository {
  final decisions = <Completer<Result<RequestDecisionData>>>[];
  final actions = <(String, int, String)>[];
  Future<Result<RequestDecisionData>> decide(String kind, int id, String text) {
    actions.add((kind, id, text));
    final gate = Completer<Result<RequestDecisionData>>();
    decisions.add(gate);
    return gate.future;
  }

  final queries = <Map<String, Object>>[];
  final lists = <Completer<Result<RequestListData>>>[];
  final lookups = <Completer<Result<RequestLookupData>>>[];
  @override
  Future<Result<RequestLookupData>> getRequestLookup() {
    final gate = Completer<Result<RequestLookupData>>();
    lookups.add(gate);
    return gate.future;
  }

  @override
  Future<Result<RequestListData>> getRequestList({
    required DateTime fromDate,
    required DateTime toDate,
    required int requestTypeId,
    required int requestStatusId,
    required String locationCode,
    required String incidentNo,
    required int page,
    required int pageSize,
  }) {
    queries.add({
      'fromDate': fromDate,
      'toDate': toDate,
      'requestTypeId': requestTypeId,
      'requestStatusId': requestStatusId,
      'locationCode': locationCode,
      'incidentNo': incidentNo,
      'page': page,
      'pageSize': pageSize,
    });
    final gate = Completer<Result<RequestListData>>();
    lists.add(gate);
    return gate.future;
  }

  @override
  Future<Result<RequestDecisionData>> approveRequest({
    required int requestId,
    required String remark,
  }) => decide('approve', requestId, remark);
  @override
  Future<Result<RequestDecisionData>> rejectRequest({
    required int requestId,
    required String reason,
  }) => decide('reject', requestId, reason);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
RequestListData page(
  List<int?> ids, {
  int total = 3,
  int number = 1,
  int size = 2,
}) => RequestListData(
  items: ids.map((id) => RequestListItemDto(id: id)).toList(),
  totalCount: total,
  page: number,
  pageSize: size,
);
ApplyRequestFilters filter(int type, {DateTime? from, DateTime? to}) =>
    ApplyRequestFilters(
      fromDate: from ?? DateTime(2026, 9, 1),
      toDate: to ?? DateTime(2026, 9, 10),
      requestTypeId: type,
      requestStatusId: 1,
      locationCode: 'D10736',
      incidentNo: 'INC-0003',
    );

void main() {
  late _Repository repo;
  late RequestListBloc bloc;
  Future<void> pending() async {
    bloc.add(filter(3));
    await tick();
    repo.lists.last.complete(
      const Success(
        RequestListData(
          items: [
            RequestListItemDto(
              id: 1,
              incidentId: 55,
              incidentNo: 'INC-55',
              locationCode: 'X',
              remark: 'original',
              requestStatus: IdNameDto(id: 1, name: 'Pending'),
            ),
            RequestListItemDto(
              id: 2,
              requestStatus: IdNameDto(id: 1, name: 'Pending'),
            ),
          ],
          totalCount: 4,
          page: 2,
          pageSize: 2,
        ),
      ),
    );
    await tick();
  }

  for (final approve in [true, false]) {
    test(
      'decision ${approve ? 'approve' : 'reject'} success uses authoritative row then same-filter page1 refresh',
      () async {
        await pending();
        final previous = bloc.state.items.first.toJson();
        bloc.add(
          approve
              ? const ApproveRequest(requestId: 1, remark: 'test approve')
              : const RejectRequest(requestId: 1, reason: 'tst rej'),
        );
        await tick();
        expect(repo.actions.single, (
          approve ? 'approve' : 'reject',
          1,
          approve ? 'test approve' : 'tst rej',
        ));
        expect(bloc.state.actingRequestId, 1);
        expect(bloc.state.page, 2);
        expect(bloc.state.loading, false);
        expect(bloc.state.items.length, 2);
        final status = IdNameDto(
          id: approve ? 2 : 3,
          name: approve ? 'Approved' : 'Rejected',
        );
        repo.decisions.single.complete(
          Success(RequestDecisionData(id: 1, requestStatus: status)),
        );
        await tick();
        expect(bloc.state.items.first.toJson(), {
          ...previous,
          'requestStatus': status.toJson(),
        });
        expect(bloc.state.actingRequestId, isNull);
        expect(bloc.state.actionFailure, isNull);
        expect(repo.queries.last['requestTypeId'], 3);
        expect(repo.queries.last['requestStatusId'], 1);
        expect(repo.queries.last['page'], 1);
        expect(repo.queries.last['locationCode'], 'D10736');
        expect(bloc.state.refreshing, true);
        repo.lists.last.complete(Success(page([2], total: 1)));
        await tick();
        expect(bloc.state.items.single.id, 2);
        expect(bloc.state.page, 1);
      },
    );
    test(
      'decision ${approve ? 'approve' : 'reject'} failure preserves rows/page/query and retry clears error',
      () async {
        await pending();
        final before = bloc.state;
        final event = approve
            ? const ApproveRequest(requestId: 1, remark: '')
            : const RejectRequest(requestId: 1, reason: '');
        bloc.add(event);
        await tick();
        repo.decisions.last.complete(const FailureResult(NetworkFailure()));
        await tick();
        expect(bloc.state.items, before.items);
        expect(bloc.state.page, 2);
        expect(bloc.state.requestStatusId, 1);
        expect(bloc.state.actingRequestId, isNull);
        expect(bloc.state.actionFailure, isA<NetworkFailure>());
        expect(repo.queries.length, 1);
        bloc.add(event);
        await tick();
        expect(bloc.state.actionFailure, isNull);
        expect(repo.actions.length, 2);
      },
    );
  }
  test(
    'single lock blocks duplicate and conflicting actions across all rows',
    () async {
      await pending();
      bloc.add(const ApproveRequest(requestId: 1, remark: 'a'));
      bloc.add(const ApproveRequest(requestId: 1, remark: 'b'));
      bloc.add(const RejectRequest(requestId: 1, reason: 'c'));
      bloc.add(const RejectRequest(requestId: 2, reason: 'd'));
      await tick();
      expect(repo.actions, [('approve', 1, 'a')]);
    },
  );
  test(
    'missing/mismatched response IDs never mutate another row and still refresh',
    () async {
      for (final id in [null, 2]) {
        await pending();
        final before = bloc.state.items;
        bloc.add(const ApproveRequest(requestId: 1, remark: ''));
        await tick();
        repo.decisions.last.complete(
          Success(
            RequestDecisionData(
              id: id,
              requestStatus: const IdNameDto(id: 2, name: 'Approved'),
            ),
          ),
        );
        await tick();
        expect(bloc.state.items, before);
        expect(bloc.state.refreshing, true);
        repo.lists.last.complete(Success(page([], total: 0)));
        await tick();
      }
    },
  );
  test(
    'decision refresh invalidates old page and uses latest changed filter',
    () async {
      await pending();
      bloc.add(const LoadMoreRequests());
      await tick();
      final oldPage = repo.lists.last;
      bloc.add(const ApproveRequest(requestId: 1, remark: ''));
      await tick();
      expect(bloc.state.loadingMore, true);
      bloc.add(filter(99));
      await tick();
      final changed = repo.lists.last;
      repo.decisions.last.complete(
        const Success(
          RequestDecisionData(
            id: 1,
            requestStatus: IdNameDto(id: 2, name: 'Approved'),
          ),
        ),
      );
      await tick();
      expect(repo.queries.last['requestTypeId'], 99);
      repo.lists.last.complete(Success(page([99], total: 1)));
      await tick();
      oldPage.complete(Success(page([8], number: 3)));
      changed.complete(Success(page([7])));
      await tick();
      expect(bloc.state.items.single.id, 99);
    },
  );
  test('invalid IDs/final statuses fail closed without writes', () async {
    await pending();
    bloc.add(const ApproveRequest(requestId: 0, remark: ''));
    await tick();
    bloc.add(const RejectRequest(requestId: 99, reason: ''));
    await tick();
    expect(repo.actions, isEmpty);
    expect(bloc.state.actionFailure, isA<ValidationFailure>());
    expect(
      canDecideRequest(
        const RequestListItemDto(
          id: 1,
          requestStatus: IdNameDto(name: 'Unknown'),
        ),
        null,
      ),
      false,
    );
    expect(
      canDecideRequest(
        const RequestListItemDto(requestStatus: IdNameDto(name: 'Pending')),
        null,
      ),
      false,
    );
  });
  setUp(() {
    repo = _Repository();
    bloc = RequestListBloc(
      getRequestLookup: GetRequestLookupUseCase(repo),
      getRequestList: GetRequestListUseCase(repo),
      approveRequest: ApproveRequestUseCase(repo),
      rejectRequest: RejectRequestUseCase(repo),
      now: () => DateTime(2030, 4, 5, 18),
    );
  });
  tearDown(() async {
    for (final gate in repo.decisions) {
      if (!gate.isCompleted) {
        gate.complete(const FailureResult(NetworkFailure()));
      }
    }
    for (final gate in repo.lists) {
      if (!gate.isCompleted) {
        gate.complete(const FailureResult(NetworkFailure()));
      }
    }
    for (final gate in repo.lookups) {
      if (!gate.isCompleted) {
        gate.complete(const FailureResult(NetworkFailure()));
      }
    }
    await tick();
    await bloc.close();
  });
  Future<void> initial({RequestListData? data}) async {
    bloc.add(const LoadRequests());
    await tick();
    repo.lists.last.complete(Success(data ?? page([1, 2])));
    await tick();
  }

  test(
    'defaults are date-only today, all filters and page size 20; no implicit calls',
    () {
      expect(bloc.state.fromDate, DateTime(2030, 4, 5));
      expect(bloc.state.toDate, DateTime(2030, 4, 5));
      expect(bloc.state.requestTypeId, -1);
      expect(bloc.state.requestStatusId, -1);
      expect(bloc.state.locationCode, '');
      expect(bloc.state.incidentNo, '');
      expect(bloc.state.page, 1);
      expect(bloc.state.pageSize, 20);
      expect(bloc.state.hasMore, false);
      expect(repo.queries, isEmpty);
      expect(repo.lookups, isEmpty);
    },
  );
  test('lookup loading/success does not automatically load list', () async {
    bloc.add(const LoadRequestLookup());
    await tick();
    expect(bloc.state.lookupLoading, true);
    const data = RequestLookupData(requestType: [RequestLookupItemDto(id: 99)]);
    repo.lookups.single.complete(const Success(data));
    await tick();
    expect(bloc.state.lookupData, same(data));
    expect(bloc.state.lookupFailure, isNull);
    expect(bloc.state.lookupLoading, false);
    expect(repo.queries, isEmpty);
  });
  test(
    'initial list loading sends exact defaults then adopts server pagination',
    () async {
      bloc.add(const LoadRequests());
      await tick();
      expect(bloc.state.loading, true);
      expect(bloc.state.items, isEmpty);
      expect(repo.queries.single, {
        'fromDate': DateTime(2030, 4, 5),
        'toDate': DateTime(2030, 4, 5),
        'requestTypeId': -1,
        'requestStatusId': -1,
        'locationCode': '',
        'incidentNo': '',
        'page': 1,
        'pageSize': 20,
      });
      repo.lists.single.complete(Success(page([1, 2])));
      await tick();
      expect(bloc.state.items.map((i) => i.id), [1, 2]);
      expect(bloc.state.totalCount, 3);
      expect(bloc.state.pageSize, 2);
      expect(bloc.state.loading, false);
      expect(bloc.state.failure, isNull);
    },
  );
  test(
    'filter application replaces content and forwards exact IDs/dates/text',
    () async {
      await initial();
      bloc.add(filter(3));
      await tick();
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.page, 1);
      expect(repo.queries.last, {
        'fromDate': DateTime(2026, 9, 1),
        'toDate': DateTime(2026, 9, 10),
        'requestTypeId': 3,
        'requestStatusId': 1,
        'locationCode': 'D10736',
        'incidentNo': 'INC-0003',
        'page': 1,
        'pageSize': 2,
      });
      repo.lists.last.complete(Success(page([9], total: 1)));
      await tick();
      expect(bloc.state.items.single.id, 9);
    },
  );
  test('invalid range rejected without swapping or calling API', () async {
    await initial();
    bloc.add(filter(3, from: DateTime(2026, 10, 1), to: DateTime(2026, 9, 1)));
    await tick();
    expect(repo.queries.length, 1);
    expect(bloc.state.failure, isA<ValidationFailure>());
    expect(bloc.state.requestTypeId, -1);
    expect(bloc.state.items.length, 2);
  });
  test(
    'unknown lookup IDs and whitespace filters pass through unchanged',
    () async {
      bloc.add(
        ApplyRequestFilters(
          fromDate: DateTime(2030, 1, 1),
          toDate: DateTime(2030, 1, 2),
          requestTypeId: 99,
          requestStatusId: 87,
          locationCode: ' X ',
          incidentNo: ' INC ',
        ),
      );
      await tick();
      expect(repo.queries.single['requestTypeId'], 99);
      expect(repo.queries.single['requestStatusId'], 87);
      expect(repo.queries.single['locationCode'], ' X ');
      expect(repo.queries.single['incidentNo'], ' INC ');
    },
  );
  test('empty response is success and prevents extra pages', () async {
    await initial(data: page([], total: 0));
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.failure, isNull);
    expect(bloc.state.hasMore, false);
    bloc.add(const LoadMoreRequests());
    await tick();
    expect(repo.queries.length, 1);
  });
  test(
    'pagination appends page 2; hasMore uses totalCount not pageSize',
    () async {
      await initial();
      bloc.add(const LoadMoreRequests());
      await tick();
      expect(bloc.state.loadingMore, true);
      expect(repo.queries.last['page'], 2);
      expect(repo.queries.last['pageSize'], 2);
      repo.lists.last.complete(Success(page([3], number: 2)));
      await tick();
      expect(bloc.state.items.map((i) => i.id), [1, 2, 3]);
      expect(bloc.state.page, 2);
      expect(bloc.state.hasMore, false);
      bloc.add(const LoadMoreRequests());
      await tick();
      expect(repo.queries.length, 2);
    },
  );
  test(
    'overlapping IDs deduplicate while every null-ID row survives',
    () async {
      await initial(data: page([1, null], total: 5));
      bloc.add(const LoadMoreRequests());
      await tick();
      repo.lists.last.complete(
        Success(page([1, 2, null, null], total: 5, number: 2)),
      );
      await tick();
      expect(bloc.state.items.map((i) => i.id), [1, null, 2, null, null]);
      expect(bloc.state.hasMore, false);
    },
  );
  test(
    'load-more failure retains page and retries same next page clearing error',
    () async {
      await initial();
      bloc.add(const LoadMoreRequests());
      await tick();
      repo.lists.last.complete(const FailureResult(NetworkFailure()));
      await tick();
      expect(bloc.state.page, 1);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.loadingMore, false);
      expect(bloc.state.loadMoreFailure, isA<NetworkFailure>());
      expect(bloc.state.failure, isNull);
      bloc.add(const LoadMoreRequests());
      await tick();
      expect(bloc.state.loadMoreFailure, isNull);
      expect(repo.queries.last['page'], 2);
      repo.lists.last.complete(Success(page([3], number: 2)));
      await tick();
      expect(bloc.state.items.length, 3);
    },
  );
  test('refresh preserves rows and filters then replaces page 1', () async {
    bloc.add(filter(3));
    await tick();
    repo.lists.last.complete(Success(page([1, 2])));
    await tick();
    bloc.add(const LoadMoreRequests());
    await tick();
    repo.lists.last.complete(Success(page([3], number: 2)));
    await tick();
    bloc.add(const RefreshRequests());
    await tick();
    expect(bloc.state.items.length, 3);
    expect(bloc.state.refreshing, true);
    expect(bloc.state.loading, false);
    expect(repo.queries.last['page'], 1);
    expect(repo.queries.last['requestTypeId'], 3);
    expect(repo.queries.last['locationCode'], 'D10736');
    repo.lists.last.complete(Success(page([8], total: 1)));
    await tick();
    expect(bloc.state.items.single.id, 8);
    expect(bloc.state.page, 1);
    expect(bloc.state.refreshing, false);
  });
  test('refresh failure preserves previous page and rows', () async {
    await initial();
    bloc.add(const RefreshRequests());
    await tick();
    repo.lists.last.complete(const FailureResult(ServerFailure()));
    await tick();
    expect(bloc.state.items.length, 2);
    expect(bloc.state.page, 1);
    expect(bloc.state.totalCount, 3);
    expect(bloc.state.refreshing, false);
    expect(bloc.state.failure, isA<ServerFailure>());
  });
  test('initial failure can retry and clears error', () async {
    bloc.add(const LoadRequests());
    await tick();
    repo.lists.last.complete(const FailureResult(NetworkFailure()));
    await tick();
    expect(bloc.state.failure, isA<NetworkFailure>());
    expect(bloc.state.loading, false);
    bloc.add(const LoadRequests());
    await tick();
    expect(bloc.state.failure, isNull);
    repo.lists.last.complete(Success(page([], total: 0)));
    await tick();
    expect(bloc.state.failure, isNull);
  });
  test('filter B wins when old filter A completes later', () async {
    bloc.add(filter(1));
    await tick();
    bloc.add(filter(2));
    await tick();
    repo.lists[1].complete(Success(page([22], total: 1)));
    await tick();
    repo.lists[0].complete(Success(page([11], total: 1)));
    await tick();
    expect(bloc.state.requestTypeId, 2);
    expect(bloc.state.items.single.id, 22);
  });
  test('old page after filter change cannot append into new results', () async {
    await initial();
    bloc.add(const LoadMoreRequests());
    await tick();
    bloc.add(filter(9));
    await tick();
    repo.lists[2].complete(Success(page([90], total: 1)));
    await tick();
    repo.lists[1].complete(Success(page([3], number: 2)));
    await tick();
    expect(bloc.state.items.single.id, 90);
    expect(bloc.state.requestTypeId, 9);
    expect(bloc.state.loadingMore, false);
  });
  test('old pagination failure cannot poison successful refresh', () async {
    await initial();
    bloc.add(const LoadMoreRequests());
    await tick();
    bloc.add(const RefreshRequests());
    await tick();
    repo.lists[2].complete(Success(page([7], total: 1)));
    await tick();
    repo.lists[1].complete(const FailureResult(ServerFailure()));
    await tick();
    expect(bloc.state.items.single.id, 7);
    expect(bloc.state.loadMoreFailure, isNull);
  });
  test(
    'duplicate initial and pagination events do not duplicate network calls',
    () async {
      bloc.add(const LoadRequests());
      bloc.add(const LoadRequests());
      await tick();
      expect(repo.queries.length, 1);
      bloc.add(const LoadMoreRequests());
      await tick();
      expect(repo.queries.length, 1);
      repo.lists[0].complete(Success(page([1, 2])));
      await tick();
      bloc.add(const LoadMoreRequests());
      bloc.add(const LoadMoreRequests());
      await tick();
      expect(repo.queries.length, 2);
    },
  );
  test('latest lookup wins independently of list version', () async {
    bloc.add(const LoadRequestLookup());
    await tick();
    bloc.add(const LoadRequestLookup());
    await tick();
    await initial();
    const data = RequestLookupData(
      requestStatus: [RequestLookupItemDto(id: 90)],
    );
    repo.lookups[1].complete(const Success(data));
    await tick();
    repo.lookups[0].complete(const FailureResult(ServerFailure()));
    await tick();
    expect(bloc.state.lookupData, same(data));
    expect(bloc.state.lookupFailure, isNull);
    expect(bloc.state.items.length, 2);
  });
  test(
    'lookup failure preserves old lookup and list; list failure preserves lookup',
    () async {
      bloc.add(const LoadRequestLookup());
      await tick();
      const data = RequestLookupData();
      repo.lookups[0].complete(const Success(data));
      await tick();
      await initial();
      bloc.add(const LoadRequestLookup());
      bloc.add(const RefreshRequests());
      await tick();
      repo.lookups[1].complete(const FailureResult(NetworkFailure()));
      await tick();
      expect(bloc.state.refreshing, true);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.lookupData, same(data));
      repo.lists.last.complete(const FailureResult(ServerFailure()));
      await tick();
      expect(bloc.state.lookupData, same(data));
      expect(bloc.state.lookupFailure, isA<NetworkFailure>());
      expect(bloc.state.failure, isA<ServerFailure>());
      expect(bloc.state.items.length, 2);
    },
  );
  test('list and lookup pending concurrently settle independently', () async {
    bloc.add(const LoadRequestLookup());
    bloc.add(const LoadRequests());
    await tick();
    repo.lookups.single.complete(const FailureResult(NetworkFailure()));
    await tick();
    expect(bloc.state.loading, true);
    repo.lists.single.complete(Success(page([1], total: 1)));
    await tick();
    expect(bloc.state.lookupFailure, isA<NetworkFailure>());
    expect(bloc.state.failure, isNull);
    expect(bloc.state.items.length, 1);
  });
  test(
    'non-advancing backend page becomes recoverable load-more failure',
    () async {
      await initial();
      bloc.add(const LoadMoreRequests());
      await tick();
      repo.lists.last.complete(Success(page([1, 2])));
      await tick();
      expect(bloc.state.page, 1);
      expect(bloc.state.loadMoreFailure, isA<ServerFailure>());
      expect(bloc.state.items.length, 2);
    },
  );
}
