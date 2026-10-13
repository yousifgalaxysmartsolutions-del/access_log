import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/engineer_locations_report_models.dart';
import '../repositories/engineer_locations_report_repository.dart';

class GetEngineerLocationsReportUseCase {
  const GetEngineerLocationsReportUseCase(this.repository);
  final EngineerLocationsReportRepository repository;
  Future<Result<EngineerLocationsReportData>> call(
    EngineerLocationsReportFilter filter,
  ) async {
    if (filter.engineerUserId <= 0) {
      return const FailureResult(UnauthorizedFailure());
    }
    if (filter.fromDate.isAfter(filter.toDate)) {
      return const FailureResult(ValidationFailure());
    }
    return repository.getReport(filter);
  }
}
