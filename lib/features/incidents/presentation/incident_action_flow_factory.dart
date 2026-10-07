import '../../../core/di/injection.dart';
import '../../forms/domain/usecases/cap_form_use_cases.dart';
import '../../forms/presentation/bloc/cap_form_cubit.dart';
import '../../forms/presentation/widgets/cap_form_capture.dart';
import '../../requests/domain/usecases/incident_request_use_case.dart';
import '../domain/actions/incident_available_action.dart';
import '../domain/usecases/get_incident_action_configuration_use_case.dart';
import '../domain/usecases/incident_execution_use_case.dart';
import '../domain/usecases/incident_geofence_use_case.dart';
import 'bloc/incident_action_configuration_cubit.dart';

/// One composition for preflight and the existing requirements page.
class IncidentActionFlowFactory {
  static IncidentActionConfigurationCubit create({
    required IncidentAvailableAction action,
    required int? incidentId,
    double? siteLatitude,
    double? siteLongitude,
    int? requestNewStatusId = IncidentRequestUseCase.confirmedNewStatusId,
    CapNativeFormCapture? capture,
  }) {
    final collector = capture ?? CapNativeFormCapture();
    return IncidentActionConfigurationCubit(
      action: action,
      incidentId: incidentId,
      executor: services<IncidentExecutionUseCase>(),
      requestExecutor: action.flow == IncidentActionFlow.request
          ? services<IncidentRequestUseCase>()
          : null,
      requestNewStatusId: requestNewStatusId,
      getConfiguration: services<GetIncidentActionConfigurationUseCase>(),
      form: CapFormCubit(services<GetCapFormUseCase>()),
      getLocation: collector.getCurrentLocation,
      validateLocation: (location) => services<IncidentGeofenceUseCase>()(
        location,
        siteLatitude: siteLatitude,
        siteLongitude: siteLongitude,
      ),
      handlePhoto: (level) =>
          resolveActionPhoto(level, capturePhoto: collector.capturePhoto),
    );
  }
}
