import '../../../../core/network/result.dart';
import '../../data/models/request_creation_models.dart';

abstract interface class RequestCreationRepository {
  Future<Result<RequestConfiguration?>> getConfiguration(
    int requestTypeId,
    int incidentId,
  );
  Future<Result<void>> create(RequestExecutionContext input);
}
