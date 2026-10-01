import '../../../../core/network/result.dart';
import '../../data/models/dashboard_stats_models.dart';

/// Reads dashboard statistics for a specific month.
abstract interface class DashboardRepository {
  Future<Result<DashboardStatsData>> getStats({required DateTime forMonth});
}
