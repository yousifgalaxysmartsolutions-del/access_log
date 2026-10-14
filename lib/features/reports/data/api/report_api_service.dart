import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/incident_report_models.dart';
import '../models/engineer_locations_report_models.dart';
import '../models/requests_path_report_models.dart';
import '../models/engineers_activity_report_models.dart';
part 'report_api_service.g.dart';

@RestApi()
abstract class ReportApiService {
  factory ReportApiService(Dio dio, {String? baseUrl}) = _ReportApiService;
  @POST('CAP/CapReport/GetIncidentsReport')
  Future<ApiResponse> getIncidentsReport(
    @Body() CapRequest<IncidentReportFilter> body,
  );
  @POST('CAP/CapReport/GetEngineerLocationsReport')
  Future<ApiResponse> getEngineerLocationsReport(
    @Body() CapRequest<EngineerLocationsReportFilter> body,
  );
  @POST('CAP/CapReport/GetRequestsPathReport')
  Future<ApiResponse> getRequestsPathReport(
    @Body() CapRequest<RequestsPathReportFilter> body,
  );
  @POST('CAP/CapReport/GetEngineersActivityReport')
  Future<ApiResponse> getEngineersActivityReport(
    @Body() CapRequest<EngineersActivityReportFilter> body,
  );
}
