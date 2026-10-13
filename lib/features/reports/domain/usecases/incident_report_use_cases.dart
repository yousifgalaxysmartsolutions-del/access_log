import '../../../../core/network/result.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../data/models/incident_report_models.dart';
import '../repositories/incident_report_repository.dart';

class GetIncidentReportUseCase {
  const GetIncidentReportUseCase(this.repository);
  final IncidentReportRepository repository;
  Future<Result<IncidentReportData>> call(IncidentReportFilter filter) =>
      repository.getReport(filter);
}

class GetReportLocationsUseCase {
  const GetReportLocationsUseCase(this.repository);
  final IncidentReportRepository repository;
  Future<Result<List<IncidentLocationDto>>> call() => repository.getLocations();
}
