import '../../../../core/network/result.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../data/models/incident_report_models.dart';

abstract interface class IncidentReportRepository {
  Future<Result<IncidentReportData>> getReport(IncidentReportFilter filter);
  Future<Result<List<IncidentLocationDto>>> getLocations();
}
