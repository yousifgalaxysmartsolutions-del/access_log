import '../../../../core/network/result.dart';
import '../../../../models/models.dart';

/// Reads incidents for a specific day, which is what the dashboard's
/// "Currently Active" section shows.
abstract interface class IncidentRepository {
  Future<Result<List<CapIncident>>> getIncidentsForDay({required DateTime day});
}
