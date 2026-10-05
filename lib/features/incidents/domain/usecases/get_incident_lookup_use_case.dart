import '../../../../core/network/result.dart';
import '../../data/models/incident_lookup_models.dart';
import '../repositories/incident_repository.dart';

class GetIncidentLookupUseCase {
  const GetIncidentLookupUseCase(this._repository);
  final IncidentRepository _repository;
  Future<Result<IncidentLookupData>> call() => _repository.getIncidentLookup();
}
