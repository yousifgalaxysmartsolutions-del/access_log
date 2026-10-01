import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../dashboard/data/repositories/demo_dashboard_repository.dart';
import '../../incidents/data/repositories/demo_incident_repository.dart';
import '../../incidents/domain/usecases/get_incident_list_use_case.dart';
import '../domain/usecases/get_dashboard_stats_use_case.dart';
import 'bloc/dashboard_bloc.dart';

/// Provides the dashboard bloc and triggers its first load.
///
/// Widget tests and the prototype flow pump `AccessLogApp` without running
/// `configureDependencies`, so there is a prototype-data fallback rather than a
/// crash. Both paths go through the same bloc and the same state.
class DashboardBlocScope extends StatelessWidget {
  const DashboardBlocScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocProvider<DashboardBloc>(
    create: (_) => _resolve()..add(const DashboardRequested()),
    child: child,
  );

  static DashboardBloc _resolve() {
    final registered = services.isRegistered<DashboardBloc>();
    if (registered) {
      return services<DashboardBloc>();
    }
    return DashboardBloc(
      getDashboardStats: GetDashboardStatsUseCase(DemoDashboardRepository()),
      getIncidentList: GetIncidentListUseCase(DemoIncidentRepository()),
    );
  }
}
