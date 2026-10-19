import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../models/periodic_photo_payload.dart';

part 'periodic_photo_api_service.g.dart';

/// CAP periodic-photo upload.
///
/// Shares the application Dio, so the existing auth interceptor, token refresh,
/// timeout policy and certificate handling all apply. Only the endpoint is new.
@RestApi()
abstract class PeriodicPhotoApiService {
  @POST('CAP/CapIncident/SavePeriodicPhoto')
  Future<ApiResponse> savePeriodicPhoto(
    @Body() CapRequest<SavePeriodicPhotoRequestData> body,
  );

  factory PeriodicPhotoApiService(Dio dio, {String? baseUrl}) =
      _PeriodicPhotoApiService;
}
