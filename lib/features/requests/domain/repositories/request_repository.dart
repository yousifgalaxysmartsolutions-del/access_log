import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';

abstract interface class RequestRepository {
  Future<Result<RequestLookupData>> getRequestLookup();

  Future<Result<RequestListData>> getRequestList({
    required DateTime fromDate,
    required DateTime toDate,
    required int requestTypeId,
    required int requestStatusId,
    required String locationCode,
    required String incidentNo,
    required int page,
    required int pageSize,
  });

  Future<Result<RequestDecisionData>> approveRequest({
    required int requestId,
    required String remark,
  });
  Future<Result<RequestDecisionData>> rejectRequest({
    required int requestId,
    required String reason,
  });
}
