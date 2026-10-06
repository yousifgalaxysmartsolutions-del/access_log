import '../../../../core/network/result.dart';
import '../../data/models/incident_action_configuration_models.dart';
import '../repositories/incident_action_configuration_repository.dart';

class GetIncidentActionConfigurationUseCase {
  const GetIncidentActionConfigurationUseCase(this.repository);
  final IncidentActionConfigurationRepository repository;
  Future<Result<IncidentActionConfiguration?>> call(int actionTypeId) =>
      repository.getConfiguration(actionTypeId);
}
