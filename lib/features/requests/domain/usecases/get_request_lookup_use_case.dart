import '../../../../core/network/result.dart';
import '../../data/models/request_models.dart';
import '../repositories/request_repository.dart';

class GetRequestLookupUseCase {
  const GetRequestLookupUseCase(this._repository);
  final RequestRepository _repository;

  Future<Result<RequestLookupData>> call() => _repository.getRequestLookup();
}
