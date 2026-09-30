import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_response.dart';
part 'copilot_api_service.g.dart';

@RestApi()
abstract class CopilotApiService {
  factory CopilotApiService(Dio dio, {String? baseUrl}) = _CopilotApiService;
  @POST('/chat/completions')
  Future<ApiResponse> complete(
    @Body() Map<String, dynamic> request,
    @Header('Authorization') String authorization,
    @CancelRequest() CancelToken? cancelToken,
  );
}
