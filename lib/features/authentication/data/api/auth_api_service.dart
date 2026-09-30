import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/auth_models.dart';
import '../../../../core/network/api_response.dart';
part 'auth_api_service.g.dart';

@RestApi()
abstract class AuthApiService {
  factory AuthApiService(Dio dio, {String? baseUrl}) = _AuthApiService;
  @POST(ApiEndpoints.login)
  @Extra({'public': true})
  Future<ApiResponse> login(@Body() LoginRequest request);
  @POST(ApiEndpoints.refresh)
  @Extra({'public': true})
  Future<ApiResponse> refresh(@Body() RefreshTokenRequest request);
}
