import '../../../../core/network/result.dart';
import '../../data/models/incident_details_models.dart';
import '../repositories/incident_details_repository.dart';

/// Loads the incident timeline.
///
/// Thin by design: the repository result is forwarded unchanged so the timeline
/// keeps one source of truth and no mapping logic lives in the domain layer.
class GetIncidentTimelineUseCase {
  const GetIncidentTimelineUseCase(this._repository);

  final IncidentDetailsRepository _repository;

  Future<Result<IncidentTimelineData>> call({required int incidentId}) =>
      _repository.getIncidentTimeline(incidentId: incidentId);
}
