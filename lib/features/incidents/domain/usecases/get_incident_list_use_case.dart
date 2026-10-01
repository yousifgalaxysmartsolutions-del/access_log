import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../repositories/incident_repository.dart';

/// Loads the incidents the dashboard shows for one day.
class GetIncidentListUseCase {
  const GetIncidentListUseCase(this._repository);

  final IncidentRepository _repository;

  Future<Result<List<CapIncident>>> call({required DateTime day}) =>
      _repository.getIncidentsForDay(day: day);
}
