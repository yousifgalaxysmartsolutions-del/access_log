import '../../../../core/network/result.dart';
import '../../data/models/incident_action_configuration_models.dart';

abstract interface class IncidentActionConfigurationRepository {
  /// A successful null configuration means no extra requirements.
  Future<Result<IncidentActionConfiguration?>> getConfiguration(
    int actionTypeId,
  );
}
