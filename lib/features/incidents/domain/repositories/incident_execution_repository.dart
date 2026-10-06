import '../../../../core/network/result.dart';
import '../actions/incident_execution_context.dart';

abstract interface class IncidentExecutionRepository {
  Future<Result<List<IncidentTeamMember>>> getTeam();
  Future<Result<void>> execute(IncidentExecutionContext context);
}
