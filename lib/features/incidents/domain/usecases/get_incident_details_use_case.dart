import '../../../../core/network/result.dart';
import '../../data/models/incident_details_models.dart';
import '../repositories/incident_details_repository.dart';

/// Loads the incident behind the details screen's "General" tab.
class GetIncidentDetailsUseCase {
  const GetIncidentDetailsUseCase(this._repository);

  final IncidentDetailsRepository _repository;

  Future<Result<IncidentDetailsData>> call({
    required int incidentId,
    required String incidentNo,
  }) => _repository.getIncidentDetails(
    incidentId: incidentId,
    incidentNo: incidentNo,
  );
}
