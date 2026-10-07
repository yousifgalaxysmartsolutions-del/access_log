import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/request_creation_models.dart';
import '../repositories/request_creation_repository.dart';

class IncidentRequestUseCase {
  const IncidentRequestUseCase(this.repository);

  /// Explicitly confirmed for CreateRequest; not derived from incident status
  /// or request type. This does not assign a meaning to the backend status.
  static const confirmedNewStatusId = 1;
  final RequestCreationRepository repository;
  Future<Result<RequestConfiguration?>> getConfiguration(
    int requestTypeId,
    int incidentId,
  ) => repository.getConfiguration(requestTypeId, incidentId);
  Future<Result<void>> create(RequestExecutionContext input) {
    if (!input.canSubmit) {
      return Future.value(
        const FailureResult(
          ValidationFailure('Request NewStatusId is not confirmed'),
        ),
      );
    }
    return repository.create(input);
  }
}
