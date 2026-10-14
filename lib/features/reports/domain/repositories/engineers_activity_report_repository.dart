import '../../../../core/network/result.dart';
import '../../data/models/engineers_activity_report_models.dart';

abstract interface class EngineersActivityReportRepository {
  Future<Result<EngineersActivityReportData>> getReport(
    EngineersActivityReportFilter filter,
  );
}
