import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../repositories/request_repository.dart';

class GetRequestListUseCase {
  const GetRequestListUseCase(this._repository);
  final RequestRepository _repository;

  Future<Result<RequestListData>> call({
    required DateTime fromDate,
    required DateTime toDate,
    required int requestTypeId,
    required int requestStatusId,
    required String locationCode,
    required String incidentNo,
    required int page,
    required int pageSize,
  }) => _repository.getRequestList(
    fromDate: fromDate,
    toDate: toDate,
    requestTypeId: requestTypeId,
    requestStatusId: requestStatusId,
    locationCode: locationCode,
    incidentNo: incidentNo,
    page: page,
    pageSize: pageSize,
  );
}
