import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../repositories/request_repository.dart';

class GetRequestDetailsUseCase {
  const GetRequestDetailsUseCase(this._repository);
  final RequestRepository _repository;

  Future<Result<RequestDetailsData>> call(int requestId) {
    if (requestId <= 0) {
      return Future.value(const FailureResult(ValidationFailure()));
    }
    return _repository.getRequestDetails(requestId: requestId);
  }
}
