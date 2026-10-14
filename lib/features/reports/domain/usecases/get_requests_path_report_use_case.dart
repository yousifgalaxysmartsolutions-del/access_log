import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/requests_path_report_models.dart';
import '../repositories/requests_path_report_repository.dart';

class GetRequestsPathReportUseCase {
  const GetRequestsPathReportUseCase(this.repository);
  final RequestsPathReportRepository repository;
  Future<Result<RequestsPathReportData>> call(
    RequestsPathReportFilter filter,
  ) async {
    if (filter.fromDate.isAfter(filter.toDate)) {
      return const FailureResult(ValidationFailure());
    }
    return repository.getReport(filter);
  }
}
