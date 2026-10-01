import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../data/repositories/demo_incident_details_repository.dart';
import '../domain/usecases/get_incident_details_use_case.dart';
import '../domain/usecases/get_incident_requests_use_case.dart';
import '../domain/usecases/get_incident_timeline_use_case.dart';
import 'bloc/incident_details_bloc.dart';

/// Provides one incident details bloc for the lifetime of the screen.
///
/// Widget tests and the prototype flow pump `AccessLogApp` without running
/// `configureDependencies`, so there is a prototype-data fallback rather than a
/// crash, mirroring [DashboardBlocScope]. Both paths go through the same bloc
/// and the same state.
///
/// The bloc is created here and nowhere else: the screen reads it from the
/// provider and the initial load is dispatched by the screen itself, because it
/// owns the incident arguments.
class IncidentDetailsBlocScope extends StatelessWidget {
  const IncidentDetailsBlocScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocProvider<IncidentDetailsBloc>(create: (_) => resolve(), child: child);

  /// Returns the registered bloc, or a prototype-backed one when DI has not
  /// run. Public because most screens push `IncidentDetailsScreen` directly
  /// instead of through `AppRoutes`, so the screen itself resolves its bloc.
  static IncidentDetailsBloc resolve() {
    if (services.isRegistered<IncidentDetailsBloc>()) {
      return services<IncidentDetailsBloc>();
    }
    final demo = DemoIncidentDetailsRepository();
    return IncidentDetailsBloc(
      getIncidentDetails: GetIncidentDetailsUseCase(demo),
      getIncidentTimeline: GetIncidentTimelineUseCase(demo),
      getIncidentRequests: GetIncidentRequestsUseCase(demo),
    );
  }
}
