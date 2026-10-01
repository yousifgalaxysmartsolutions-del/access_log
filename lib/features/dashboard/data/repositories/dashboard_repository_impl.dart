import 'package:flutter/foundation.dart';

import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../api/dashboard_api_service.dart';
import '../models/dashboard_stats_models.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._api, this._context);

  final DashboardApiService _api;
  final ApiRequestContextProvider _context;

  @override
  Future<Result<DashboardStatsData>> getStats({
    required DateTime forMonth,
  }) async {
    final envelope = await _context.wrap(
      DashboardStatsRequestData(month: forMonth.month, year: forMonth.year),
      authenticationMessage: 'Sign in again to load dashboard statistics',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getDashboardStats(data);
        final parsed = GeneralResponse.parseOrThrow<DashboardStatsData>(
          response,
          (raw) {
            final json = capMap(raw);
            if (DashboardStatsData.looksUnrecognised(json)) {
              debugPrint(
                '[CAP] GetDashboardStats returned no known metric. '
                'data keys: ${json.keys.toList()}',
              );
            }
            return DashboardStatsData.fromJson(json);
          },
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load dashboard statistics',
        );
        return parsed.data!;
      }),
    };
  }
}
