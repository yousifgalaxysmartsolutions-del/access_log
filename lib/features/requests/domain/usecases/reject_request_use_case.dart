import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../repositories/request_repository.dart';

class RejectRequestUseCase {
  const RejectRequestUseCase(this._repository);
  final RequestRepository _repository;

  Future<Result<RequestDecisionData>> call({
    required int requestId,
    required String reason,
  }) => _repository.rejectRequest(requestId: requestId, reason: reason);
}
