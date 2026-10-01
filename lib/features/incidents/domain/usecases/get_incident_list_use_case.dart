import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../repositories/incident_repository.dart';

/// Loads a day or inclusive range, shared by the dashboard and incident list.
class GetIncidentListUseCase {
  const GetIncidentListUseCase(this._repository);

  final IncidentRepository _repository;

  Future<Result<List<CapIncident>>> call({
    required DateTime day,
    DateTime? toDate,
  }) => _repository.getIncidentsForDay(day: day, toDate: toDate);
}
