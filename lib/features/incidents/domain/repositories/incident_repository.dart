import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../../data/models/incident_lookup_models.dart';

/// Reads a specific day, or an inclusive range when `toDate` is supplied.
abstract interface class IncidentRepository {
  Future<Result<IncidentLookupData>> getIncidentLookup();
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
    DateTime? toDate,
  });
}
