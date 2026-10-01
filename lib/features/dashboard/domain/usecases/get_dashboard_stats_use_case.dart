import '../../../../core/network/result.dart';
import '../../data/models/dashboard_stats_models.dart';
import '../repositories/dashboard_repository.dart';

/// Loads the CAP dashboard statistics for the requested month.
class GetDashboardStatsUseCase {
  const GetDashboardStatsUseCase(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardStatsData>> call({required DateTime forMonth}) =>
      _repository.getStats(forMonth: forMonth);
}
