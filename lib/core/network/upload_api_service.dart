import 'dart:io';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'api_response.dart';
part 'upload_api_service.g.dart';

/// Template endpoint: confirm the backend contract before using in UI.
@RestApi()
abstract class UploadApiService {
  factory UploadApiService(Dio dio, {String? baseUrl}) = _UploadApiService;
  @POST('/attachments')
  @MultiPart()
  Future<ApiResponse> upload(@Part(name: 'file') File file,
    @Queries() Map<String, dynamic> query,
    @Header('X-Request-ID') String requestId,
    @CancelRequest() CancelToken? cancelToken,
    @SendProgress() ProgressCallback? progress);
}
