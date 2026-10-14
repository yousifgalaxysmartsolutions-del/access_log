import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/engineers_activity_report_models.dart';
import '../repositories/engineers_activity_report_repository.dart';

class GetEngineersActivityReportUseCase {
  const GetEngineersActivityReportUseCase(this.repository);
  final EngineersActivityReportRepository repository;
  Future<Result<EngineersActivityReportData>> call(
    EngineersActivityReportFilter filter,
  ) async {
    if (filter.fromDate.isAfter(filter.toDate)) {
      return const FailureResult(ValidationFailure());
    }
    final result = await repository.getReport(filter);
    if (result is Success<EngineersActivityReportData> &&
        result.data.groupBy != filter.groupBy) {
      return const FailureResult(ServerFailure('Unexpected report grouping'));
    }
    return result;
  }
}
