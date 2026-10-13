import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../../dashboard/data/api/dashboard_api_service.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import '../../domain/repositories/incident_report_repository.dart';
import '../api/report_api_service.dart';
import '../models/incident_report_models.dart';

class IncidentReportRepositoryImpl implements IncidentReportRepository {
  IncidentReportRepositoryImpl(this.api, this.dashboard, this.context);
  final ReportApiService api;
  final DashboardApiService dashboard;
  final ApiRequestContextProvider context;
  @override
  Future<Result<IncidentReportData>> getReport(
    IncidentReportFilter filter,
  ) async {
    final envelope = await context.wrap(
      filter,
      authenticationMessage: 'Sign in again to load reports',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await api.getIncidentsReport(data);
        return GeneralResponse.parseOrThrow<IncidentReportData>(
          response,
          (raw) => IncidentReportData.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load incident report',
          endpoint: 'CAP/CapReport/GetIncidentsReport',
          model: 'IncidentReportData',
        ).data!;
      }),
    };
  }

  @override
  Future<Result<List<IncidentLocationDto>>> getLocations() async {
    final envelope = await context.wrap<Null>(
      null,
      authenticationMessage: 'Sign in again to load locations',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await dashboard.getLocations(data);
        return GeneralResponse.parseOrThrow<List<IncidentLocationDto>>(
          response,
          (raw) => List.unmodifiable(
            (raw as List).map(
              (e) => IncidentLocationDto.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            ),
          ),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load locations',
          endpoint: 'CAP/CapDashboard/GetLocations',
          model: 'IncidentLocationDto',
        ).data!;
      }),
    };
  }
}
