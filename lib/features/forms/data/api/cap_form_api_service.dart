import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/cap_form_models.dart';
part 'cap_form_api_service.g.dart';

/// Uses the application's authenticated Dio; no separate token/network stack.
@RestApi()
abstract class CapFormApiService {
  factory CapFormApiService(Dio dio, {String? baseUrl}) = _CapFormApiService;
  @POST('CAP/CapLookup/GetFormQuestion')
  Future<ApiResponse> getForm(@Body() CapRequest<GetCapFormPayload> body);
  @POST('CAP/CapIncident/IncidentStatusChange')
  Future<ApiResponse> submit(@Body() CapRequest<IncidentFormSubmission> body);
}
