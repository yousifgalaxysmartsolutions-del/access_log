import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../repositories/request_repository.dart';

class ApproveRequestUseCase {
  const ApproveRequestUseCase(this._repository);
  final RequestRepository _repository;

  Future<Result<RequestDecisionData>> call({
    required int requestId,
    required String remark,
  }) => _repository.approveRequest(requestId: requestId, remark: remark);
}
