import '../../../../core/network/result.dart';
import '../../../../mock/mock_data.dart';
import '../../../../models/models.dart';
import '../../../incidents/data/repositories/demo_incident_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../models/dashboard_stats_models.dart';

/// Prototype dashboard numbers, used while the app runs in mock-auth mode.
///
/// The dashboard reads from this through the same repository interface as the
/// real CAP endpoint, so the screen, bloc and tests never need a special case.
class DemoDashboardRepository implements DashboardRepository {
  @override
  Future<Result<DashboardStatsData>> getStats({
    required DateTime forMonth,
  }) async {
    final month = MockData.capIncidents
        .where((item) => item.dateTime.year == _prototypeYear)
        .where((item) => item.dateTime.month == _prototypeMonth)
        .toList();

    int count(CapIncidentStatus status) =>
        month.where((item) => item.status == status).length;

    final completed = count(CapIncidentStatus.completed);
    final open = month
        .where(
          (item) =>
              item.status != CapIncidentStatus.completed &&
              item.status != CapIncidentStatus.cancelled,
        )
        .length;

    return Success(
      DashboardStatsData(
        totalIncidents: month.length,
        openIncidents: open,
        inProgress: count(CapIncidentStatus.inProcess),
        completed: completed,
        onHold: count(CapIncidentStatus.hold),
        todaysActivities: DemoIncidentRepository.prototypeDayCount,
        needApproval: count(CapIncidentStatus.needApproval),
        monthSummary: MonthSummary(
          year: _prototypeYear,
          month: _prototypeMonth,
          totalIncident: month.length,
          completed: completed,
          percentage: month.isEmpty ? 0 : completed / month.length * 100,
        ),
      ),
    );
  }

  static const int _prototypeYear = 2026;
  static const int _prototypeMonth = 8;
}
