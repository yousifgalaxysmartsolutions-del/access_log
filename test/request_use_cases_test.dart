import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_lookup_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_list_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/approve_request_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/reject_request_use_case.dart';

class _Repository implements RequestRepository {
  final calls = <String>[];
  Map<String, Object?> parameters = {};
  Result<RequestLookupData> lookup = const Success(RequestLookupData());
  Result<RequestListData> list = const Success(
    RequestListData(totalCount: 71, page: 4, pageSize: 20),
  );
  Result<RequestDecisionData> decision = const Success(
    RequestDecisionData(id: 99),
  );
  @override
  Future<Result<RequestLookupData>> getRequestLookup() async {
    calls.add('lookup');
    return lookup;
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
  }) async {
    calls.add('list');
    parameters = {
      'fromDate': fromDate,
      'toDate': toDate,
      'requestTypeId': requestTypeId,
      'requestStatusId': requestStatusId,
      'locationCode': locationCode,
      'incidentNo': incidentNo,
      'page': page,
      'pageSize': pageSize,
    };
    return list;
  }

  @override
  Future<Result<RequestDecisionData>> approveRequest({
    required int requestId,
    required String remark,
  }) async {
    calls.add('approve');
    parameters = {'requestId': requestId, 'remark': remark};
    return decision;
  }

  @override
  Future<Result<RequestDecisionData>> rejectRequest({
    required int requestId,
    required String reason,
  }) async {
    calls.add('reject');
    parameters = {'requestId': requestId, 'reason': reason};
    return decision;
  }
}

void main() {
  for (final failure in [false, true]) {
    test(
      'lookup forwards ${failure ? 'failure' : 'success'} unchanged exactly once',
      () async {
        final repo = _Repository();
        if (failure) repo.lookup = const FailureResult(NetworkFailure());
        expect(await GetRequestLookupUseCase(repo)(), same(repo.lookup));
        expect(repo.calls, ['lookup']);
      },
    );
    test(
      'list forwards every parameter and ${failure ? 'failure' : 'success'} unchanged',
      () async {
        final repo = _Repository();
        if (failure) repo.list = const FailureResult(ServerFailure());
        final from = DateTime(2026, 9, 1), to = DateTime(2026, 9, 10);
        final result = await GetRequestListUseCase(repo)(
          fromDate: from,
          toDate: to,
          requestTypeId: 3,
          requestStatusId: 1,
          locationCode: 'D10736',
          incidentNo: 'INC-0003',
          page: 4,
          pageSize: 20,
        );
        expect(result, same(repo.list));
        expect(repo.calls, ['list']);
        expect(repo.parameters, {
          'fromDate': from,
          'toDate': to,
          'requestTypeId': 3,
          'requestStatusId': 1,
          'locationCode': 'D10736',
          'incidentNo': 'INC-0003',
          'page': 4,
          'pageSize': 20,
        });
        expect(repo.parameters['fromDate'], same(from));
        expect(repo.parameters['toDate'], same(to));
      },
    );
    test(
      'approve forwards remark and ${failure ? 'failure' : 'success'} unchanged',
      () async {
        final repo = _Repository();
        if (failure) repo.decision = const FailureResult(UnauthorizedFailure());
        expect(
          await ApproveRequestUseCase(repo)(
            requestId: 1,
            remark: 'test approve',
          ),
          same(repo.decision),
        );
        expect(repo.calls, ['approve']);
        expect(repo.parameters, {'requestId': 1, 'remark': 'test approve'});
      },
    );
    test(
      'reject forwards reason and ${failure ? 'failure' : 'success'} unchanged',
      () async {
        final repo = _Repository();
        if (failure) repo.decision = const FailureResult(ValidationFailure());
        expect(
          await RejectRequestUseCase(repo)(requestId: 2, reason: 'tst rej'),
          same(repo.decision),
        );
        expect(repo.calls, ['reject']);
        expect(repo.parameters, {'requestId': 2, 'reason': 'tst rej'});
      },
    );
  }
  test(
    'use cases do not normalize dates, filters, remarks or reasons',
    () async {
      final repo = _Repository();
      final from = DateTime.utc(2032, 4, 5, 16, 30),
          to = DateTime.utc(2032, 4, 6, 17);
      await GetRequestListUseCase(repo)(
        fromDate: from,
        toDate: to,
        requestTypeId: 99,
        requestStatusId: 88,
        locationCode: ' D10736 ',
        incidentNo: ' INC-0003 ',
        page: 7,
        pageSize: 33,
      );
      expect(repo.parameters, {
        'fromDate': from,
        'toDate': to,
        'requestTypeId': 99,
        'requestStatusId': 88,
        'locationCode': ' D10736 ',
        'incidentNo': ' INC-0003 ',
        'page': 7,
        'pageSize': 33,
      });
      await ApproveRequestUseCase(repo)(requestId: 5, remark: ' ملاحظة ');
      expect(repo.parameters['remark'], ' ملاحظة ');
      await RejectRequestUseCase(repo)(requestId: 6, reason: ' سبب ');
      expect(repo.parameters['reason'], ' سبب ');
      expect(repo.calls, ['list', 'approve', 'reject']);
    },
  );
}
