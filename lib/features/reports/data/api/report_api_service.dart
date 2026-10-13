import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/incident_report_models.dart';
part 'report_api_service.g.dart';

@RestApi()
abstract class ReportApiService {
  factory ReportApiService(Dio dio, {String? baseUrl}) = _ReportApiService;
  @POST('CAP/CapReport/GetIncidentsReport')
  Future<ApiResponse> getIncidentsReport(
    @Body() CapRequest<IncidentReportFilter> body,
  );
}
