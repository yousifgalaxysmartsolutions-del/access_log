import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/request_models.dart';
import '../models/request_creation_models.dart';

part 'request_api_service.g.dart';

/// Supply the application's existing Dio to retain authentication/interceptors.
/// Responses use the shared GeneralResponse-compatible envelope convention.
@RestApi()
abstract class RequestApiService {
  factory RequestApiService(Dio dio, {String? baseUrl}) = _RequestApiService;

  @POST('CAP/CapConfiguration/GetRequestConfiguration')
  Future<ApiResponse> getRequestConfiguration(
    @Body() CapRequest<RequestConfigurationInput> body,
  );

  @POST('CAP/CapRequest/CreateRequest')
  Future<ApiResponse> createRequest(
    @Body() CapRequest<RequestExecutionContext> body,
  );

  /// Build this body with CapRequest.metadataOnly: this contract has no data.
  @POST('CAP/CapLookup/GetAllRequestLookup')
  Future<ApiResponse> getAllRequestLookup(@Body() CapRequest<Null> body);

  @POST('CAP/CapRequest/GetRequestList')
  Future<ApiResponse> getRequestList(
    @Body() CapRequest<RequestListRequestData> body,
  );

  @POST('CAP/CapRequest/RequestApprove')
  Future<ApiResponse> requestApprove(
    @Body() CapRequest<RequestApproveData> body,
  );

  @POST('CAP/CapRequest/RequestReject')
  Future<ApiResponse> requestReject(@Body() CapRequest<RequestRejectData> body);
}
