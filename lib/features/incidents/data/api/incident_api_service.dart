import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../data/models/incident_details_models.dart';
import '../../data/models/incident_list_models.dart';

part 'incident_api_service.g.dart';

/// CAP incident queries.
///
/// Shares the application Dio so the existing auth interceptor, timeout policy
/// and 401 refresh handling apply.
@RestApi()
abstract class IncidentApiService {
  factory IncidentApiService(Dio dio, {String? baseUrl}) = _IncidentApiService;

  @POST('CAP/CapLookup/GetAllIncidentLookup')
  Future<ApiResponse> getAllIncidentLookup(@Body() CapRequest<Null> body);

  @POST('CAP/CapIncident/GetIncidentList')
  Future<ApiResponse> getIncidentList(
    @Body() CapRequest<IncidentListRequestData> body,
  );

  /// Incident details for the "General" tab.
  @POST('CAP/CapIncident/GetIncidentDetails')
  Future<ApiResponse> getIncidentDetails(
    @Body() CapRequest<IncidentDetailsRequestData> body,
  );

  /// Incident timeline.
  ///
  /// Like every other endpoint here the transport returns the shared untyped
  /// [ApiResponse] envelope and `GeneralResponse.parseOrThrow` decodes it into
  /// [IncidentTimelineData] in the repository.
  @POST('CAP/CapIncident/GetIncidentTimeline')
  Future<ApiResponse> getIncidentTimeline(
    @Body() CapRequest<IncidentTimelineRequestData> body,
  );

  /// Requests attached to the incident ("Related Requests" tab).
  @POST('CAP/CapIncident/GetIncidentRequests')
  Future<ApiResponse> getIncidentRequests(
    @Body() CapRequest<IncidentRequestsRequestData> body,
  );
}
