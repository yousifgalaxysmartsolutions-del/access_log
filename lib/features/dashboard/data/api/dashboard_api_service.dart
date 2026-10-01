import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../data/models/dashboard_stats_models.dart';

part 'dashboard_api_service.g.dart';

/// CAP dashboard statistics.
///
/// Uses the shared application Dio so the existing auth interceptor, timeout
/// policy, logging and 401 refresh handling all apply.
@RestApi()
abstract class DashboardApiService {
  factory DashboardApiService(Dio dio, {String? baseUrl}) =
      _DashboardApiService;

  @POST('CAP/CapDashboard/GetDashboardStats')
  Future<ApiResponse> getDashboardStats(
    @Body() CapRequest<DashboardStatsRequestData> body,
  );
}
