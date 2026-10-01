import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../data/models/incident_list_models.dart';

part 'incident_api_service.g.dart';

/// CAP incident queries.
///
/// Shares the application Dio so the existing auth interceptor, timeout policy
/// and 401 refresh handling apply.
@RestApi()
abstract class IncidentApiService {
  factory IncidentApiService(Dio dio, {String? baseUrl}) = _IncidentApiService;

  @POST('CAP/CapIncident/GetIncidentList')
  Future<ApiResponse> getIncidentList(
    @Body() CapRequest<IncidentListRequestData> body,
  );
}
