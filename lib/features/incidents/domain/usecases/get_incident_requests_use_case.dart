import '../../../../core/network/result.dart';
import '../../data/models/incident_details_models.dart';
import '../repositories/incident_details_repository.dart';

/// Loads the requests attached to an incident ("Related Requests" tab).
class GetIncidentRequestsUseCase {
  const GetIncidentRequestsUseCase(this._repository);

  final IncidentDetailsRepository _repository;

  Future<Result<IncidentRequestsData>> call({required int incidentId}) =>
      _repository.getIncidentRequests(incidentId: incidentId);
}
