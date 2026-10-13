import '../../../../core/network/result.dart';
import '../../data/models/engineer_locations_report_models.dart';

abstract interface class EngineerLocationsReportRepository {
  Future<Result<EngineerLocationsReportData>> getReport(
    EngineerLocationsReportFilter filter,
  );
}
