import '../../../../core/network/result.dart';
import '../../data/models/requests_path_report_models.dart';

abstract interface class RequestsPathReportRepository {
  Future<Result<RequestsPathReportData>> getReport(
    RequestsPathReportFilter filter,
  );
}
