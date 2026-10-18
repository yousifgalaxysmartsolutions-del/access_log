import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/gps_tracking_sync_payload.dart';

part 'gps_tracking_api_service.g.dart';

/// CAP GPS-tracking upload.
///
/// Shares the application Dio, so the existing auth interceptor, token refresh,
/// timeout policy and certificate handling all apply. Only the endpoint is new.
@RestApi()
abstract class GpsTrackingApiService {
  @POST('CAP/CapAuth/GpsTracking')
  Future<ApiResponse> uploadGpsTracking(
    @Body() CapRequest<GpsTrackingSyncRequestData> body,
  );

  factory GpsTrackingApiService(Dio dio, {String? baseUrl}) =
      _GpsTrackingApiService;
}
