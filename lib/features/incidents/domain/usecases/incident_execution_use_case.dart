import '../../../../core/network/result.dart';
import '../actions/incident_execution_context.dart';
import '../repositories/incident_execution_repository.dart';

/// Continues an already collected action without repeating its requirements.
class IncidentExecutionUseCase {
  const IncidentExecutionUseCase(this.repository);
  final IncidentExecutionRepository repository;
  Future<Result<List<IncidentTeamMember>>> getTeam() => repository.getTeam();
  Future<Result<void>> execute(IncidentExecutionContext context) =>
      repository.execute(context);
}
